% 현재 폴더와 모든 하위 폴더(TS-EMO 라이브러리)를 매틀랩 경로에 추가
addpath(genpath(pwd)); 

%% 1. 가상 반응기 모델 학습 (Case 2: N-benzylation)
disp('Case 2 가상 반응기 데이터를 불러오고 학습을 시작합니다...');

% 데이터 불러오기 (컬럼 순서를 꼭 위 가이드에 맞춰주세요)
data = readtable('table_s5.csv');

% 입력 변수: [Flow_rate, 7:6 Ratio, Solvent:6 Ratio, Temp]
X_train = data{:, 1:4}; 

% 출력 변수 (논문 식 (4) 적용)
Y_STY_log = -log(data{:, 6});        % STY 극대화 -> 음수 로그
Y_Impurity_log = log(data{:, 5});    % 불순물 극소화 -> 그냥 로그

% 랜덤 포레스트 모델 학습
Mdl_STY = fitrensemble(X_train, Y_STY_log, 'Method', 'Bag');
Mdl_Impurity = fitrensemble(X_train, Y_Impurity_log, 'Method', 'Bag');
disp('Case 2 가상 반응기 학습 완료!');

%% 2. TS-EMO 알고리즘 세팅 및 연동
disp('TS-EMO 최적화를 시작합니다...');

% (1) 목적 함수 연결
obj_fun = @(x) virtual_reactor_case2(x, Mdl_STY, Mdl_Impurity);

% (2) 초기 20개 데이터 추출 (TS-EMO 알고리즘의 초기 학습용)
%X_init = X_train(1:20, :);
%Y_init = [Y_STY_log(1:20), Y_Impurity_log(1:20)];

% 변경: 전체 데이터 중 랜덤하게 20개 추출 (일반화 성능 테스트)
rand_idx = randperm(size(X_train, 1), 20); 
X_init = X_train(rand_idx, :);
Y_init = [Y_STY_log(rand_idx), Y_Impurity_log(rand_idx)];

% (3) 변수 탐색 범위 설정 (논문 Table 1 - Case 2 기준)
% [Flow_rate, 7:6 Ratio, Solvent:6 Ratio, Temp]
lower_bounds = [0.2, 1.0, 0.5, 110];
upper_bounds = [0.4, 5.0, 1.0, 150];

% (4) TSEMO_V4.m 에러 방지를 위한 옵션 세팅
Opt.maxeval = 58;                 % 논문에서는 추가로 58번 실험했으나, 시뮬레이션 속도를 위해 40번으로 설정
Opt.NoOfBachSequential = 1;       
Opt.pop = 100;                    
Opt.Generation = 100;             

% GP(가우시안 프로세스) 세부 옵션 설정
for i = 1:2
    Opt.GP(i).matern = 5;         
    Opt.GP(i).fun_eval = 100;     
    Opt.GP(i).nSpectralpoints = 4000; 
end

% (5) TSEMO_V4 실행!
[Xpareto, Ypareto, X_final, Y_final] = TSEMO_V4(obj_fun, X_init, Y_init, lower_bounds, upper_bounds, Opt);

disp('최적화 시뮬레이션 종료!');

%% 3. 논문 스타일 시각화 (Case 2: N-benzylation)
disp('Case 2 논문 스타일로 그래프를 생성합니다...');

% 1) 데이터 역변환 (로그 스케일 -> 실제 수치)
% Y(:, 1) = -ln(STY) 이므로 exp(-Y)
% Y(:, 2) = ln(% Impurity) 이므로 exp(Y)
actual_STY_all = exp(-Y_final(:, 1));      
actual_Impurity_all = exp(Y_final(:, 2));   

actual_STY_pareto = exp(-Ypareto(:, 1));
actual_Impurity_pareto = exp(Ypareto(:, 2));

figure('Color', 'w', 'Name', 'Case 2 Pareto Front'); hold on;

% 2) 초기 20개 점 (LHC) - 검은색 네모
scatter(actual_STY_all(1:20), actual_Impurity_all(1:20), 40, ...
        's', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'k', 'DisplayName', 'LHC');

% 3) TS-EMO가 추가로 찾은 점들 (21번 이후) - 주황색 X
scatter(actual_STY_all(21:end), actual_Impurity_all(21:end), 60, ...
        'x', 'LineWidth', 1.5, 'MarkerEdgeColor', [1 0.5 0], 'DisplayName', 'TS-EMO');

% 4) 파레토 전선 (Pareto Front) - 빨간색 실선
% STY 기준으로 정렬하여 선이 꼬이지 않게 함
[sorted_STY, sortIdx] = sort(actual_STY_pareto);
sorted_Impurity = actual_Impurity_pareto(sortIdx);
plot(sorted_STY, sorted_Impurity, 'r-', 'LineWidth', 2, 'DisplayName', 'Pareto Front');

% 5) 그래프 디테일 설정
xlabel('STY / kg m^{-3} h^{-1}', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Impurity / %', 'FontSize', 12, 'FontWeight', 'bold');
title('Case Study Two: N-benzylation', 'FontSize', 14);
legend('Location', 'northeast');
grid on;
box on;

% 축 범위 조정 (논문 Figure 3 기준 - 필요시 조절)
% xlim([0 400]);
% ylim([0 20]);

hold off;

function Y_pred = virtual_reactor_case2(X_input, Mdl_STY, Mdl_Impurity)
    % X_input: TS-EMO가 제안하는 [1 x 4] 크기의 새로운 실험 조건
    % [Flow_rate, Ratio_7_to_6, Solvent_to_6, Temp]
    
    % 가상 반응기(학습된 랜덤 포레스트 모델)를 돌려서 결과 예측
    pred_STY = predict(Mdl_STY, X_input);
    pred_Impurity = predict(Mdl_Impurity, X_input);
    
    % TS-EMO 알고리즘을 위해 배열로 묶어서 반환: [-ln(STY), ln(% Impurity)]
    Y_pred = [pred_STY, pred_Impurity];
end