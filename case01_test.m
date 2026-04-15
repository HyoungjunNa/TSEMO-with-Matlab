addpath(genpath(pwd));

%% 1. 가상 반응기 모델 학습 및 기준점 설정
disp('데이터를 불러오고 Ground Truth 모델을 학습합니다...');
data = readtable('table_s3.csv');
X_all = data{:, 1:4}; 
Y_STY_log = -log(data{:, 6});      
Y_Efactor_log = log(data{:, 5});   
Y_all = [Y_STY_log, Y_Efactor_log];

% HV 계산을 위한 양수 변환(Shift) 로직
offset = abs(min(Y_all)) + 1;
Y_all_pos = Y_all + offset;

% 전체 데이터를 학습한 Ground Truth 모델
Mdl_STY_GT = fitrensemble(X_all, Y_STY_log, 'Method', 'Bag');
Mdl_EF_GT = fitrensemble(X_all, Y_Efactor_log, 'Method', 'Bag');

% [추가] 100% 기준이 될 정답지의 HV 계산
front_gt = paretofront(Y_all_pos);
Y_pareto_gt = Y_all_pos(front_gt, :);
ref_point_pos = max(Y_all_pos) * 1.1; % 기준점 설정
base_hv = hypervolume_author(Y_pareto_gt, ref_point_pos, 5000);

% RMSE 측정을 위한 테스트셋 분리 (20%)
cv = cvpartition(size(X_all,1), 'HoldOut', 0.2);
X_test = X_all(test(cv), :);
Y_test = Y_all(test(cv), :);

%% 2. TS-EMO 알고리즘 실행
disp('TS-EMO 최적화를 시작합니다...');
obj_fun = @(x) [predict(Mdl_STY_GT, x), predict(Mdl_EF_GT, x)];

%  초기 n개 데이터 추출 (TS-EMO 알고리즘의 초기 학습용)
n = 20;
X_init = X_train(1:n, :);
Y_init = [Y_STY_log(1:n), Y_Efactor_log(1:n)];

% 변경: 전체 데이터 중 랜덤하게 n개 추출 (일반화 성능 테스트)
%rand_idx = randperm(size(X_all, 1), n); 
%X_init = X_all(rand_idx, :);
%Y_init = Y_all(rand_idx, :);

% TS-EMO 옵션 설정 (N = 20 + 48 = 68회)
Opt.maxeval = 5;                 
Opt.NoOfBachSequential = 1;       
Opt.pop = 100; Opt.Generation = 100;
for i = 1:2
    Opt.GP(i).matern = 5; Opt.GP(i).fun_eval = 100; Opt.GP(k).nSpectralpoints = 4000;
end

[Xpareto, Ypareto, X_final, Y_final] = TSEMO_V4(obj_fun, X_init, Y_init, [0.5, 1.0, 0.1, 60], [2.0, 5.0, 0.5, 140], Opt);

%% 3. 성능 지표 계산 (RMSE & HV)
disp('성능 지표를 계산 중입니다...');

% 현재 찾은 데이터(Y_final)로 학습한 모델의 RMSE
Mdl_S_now = fitrensemble(X_final, Y_final(:,1), 'Method', 'Bag');
Mdl_E_now = fitrensemble(X_final, Y_final(:,2), 'Method', 'Bag');
pred = [predict(Mdl_S_now, X_test), predict(Mdl_E_now, X_test)];
current_rmse = sqrt(mean((Y_test(:) - pred(:)).^2));

% 현재 파레토 전선의 HV 및 유사도
Ypareto_pos = Ypareto + offset;
current_hv = hypervolume_author(Ypareto_pos, ref_point_pos, 5000);
similarity = (current_hv / base_hv) * 100;

% --- [R2 계산 로직 추가] ---
% 예측값을 각각의 변수로 저장
pred_S = predict(Mdl_S_now, X_test);
pred_E = predict(Mdl_E_now, X_test);
% 1. STY에 대한 R2
SS_res_S = sum((Y_test(:,1) - pred_S).^2);        % 잔차 제곱합
SS_tot_S = sum((Y_test(:,1) - mean(Y_test(:,1))).^2); % 총 제곱합
R2_STY = 1 - (SS_res_S / SS_tot_S);

% 2. E-factor에 대한 R2
SS_res_E = sum((Y_test(:,2) - pred_E).^2);
SS_tot_E = sum((Y_test(:,2) - mean(Y_test(:,2))).^2);
R2_EF = 1 - (SS_res_E / SS_tot_E);

% 로그 출력
fprintf(' - STY R2 Score: %.4f\n', R2_STY);
fprintf(' - E-factor R2 Score: %.4f\n', R2_EF);


%% 4. 결과 출력 (요청하신 표 형식)
fprintf('\n====================================================================\n');
fprintf('   실험 횟수(N) |  R2_STY  |  R2_EF  |   평균 HV   |  HV 유사도(%%) \n');
fprintf('--------------------------------------------------------------------\n');
fprintf('      %3d회     |   %.4f    |   %.4f   |   %.4f    |     %.1f%% \n', ...
        size(Y_final, 1), R2_STY, R2_EF, current_hv, similarity);
fprintf('====================================================================\n');

%% 5. 논문 스타일 시각화 (Figure 2 재현)
actual_STY_all = exp(-Y_final(:, 1));      
actual_Efactor_all = exp(Y_final(:, 2));   
actual_STY_pareto = exp(-Ypareto(:, 1));
actual_Efactor_pareto = exp(Ypareto(:, 2));

figure('Color', 'w'); hold on;
scatter(actual_STY_all(1:n), actual_Efactor_all(1:n), 40, 's', 'k', 'MarkerFaceColor', 'k', 'DisplayName', 'LHC');
scatter(actual_STY_all(21:end), actual_Efactor_all(21:end), 60, 'x', 'LineWidth', 1.5, 'MarkerEdgeColor', [1 0.5 0], 'DisplayName', 'TS-EMO');
[sorted_STY, sortIdx] = sort(actual_STY_pareto);
plot(sorted_STY, actual_Efactor_pareto(sortIdx), 'r-', 'LineWidth', 2, 'DisplayName', 'Pareto Front');

xlabel('STY / kg m^{-3} h^{-1}'); ylabel('E-factor');
title(sprintf('Optimization Results (N=%d)', size(Y_final, 1)));
legend('Location', 'northeast'); grid on; box on;
xlim([0 15000]); ylim([0 2.5]);
hold off;

%% 보조 함수 (HV 계산)
function v = hypervolume_author(P, r, N)
    P = P * diag(1./r); [n, d] = size(P); C = rand(N, d);
    fDominated = false(N, 1); lB = min(P);
    fcheck = all(bsxfun(@gt, C, lB), 2);
    for k = 1:n
        if any(fcheck)
            f = all(bsxfun(@gt, C(fcheck,:), P(k,:)), 2);
            fDominated(fcheck) = fDominated(fcheck) | f;
        end
    end
    v = sum(fDominated) / N;
end