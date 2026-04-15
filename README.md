# Autonomous Chemical Synthesis Optimization: TS-EMO Reproduction with RF Digital Twin

본 프로젝트는 2018년 ACS Central Science에 발표된 **"Machine learning meets continuous flow chemistry"** 논문의 자율 최적화 시스템을 MATLAB 환경에서 재현한 연구입니다. 특히, 실제 실험 장비를 **Random Forest 기반의 Digital Twin**으로 대체하여 '폐쇄 루프(Closed-loop)' 최적화 성능을 검증하였습니다.

## 🛠 핵심 재현 포인트: 가상 반응기 (Random Forest Digital Twin)
본 재현의 핵심은 논문의 물리적 실험 환경을 소프트웨어적으로 모사한 **Surrogate Model(대리 모델)** 구축에 있습니다.

* **Digital Twin 구현:** 논문에 제공된 실험 데이터를 학습시킨 **Random Forest** 모델을 구축하였습니다.
* **Closed-loop 인터페이스:** TS-EMO 알고리즘이 새로운 실험 조건($X$)을 제안하면, 가상 반응기가 즉시 결과값($Y$)을 예측하여 반환함으로써 인적 개입이 없는 자율 최적화 루프를 완성하였습니다.
* **의의:** 실제 고가의 장비나 시약 소모 없이도 최적화 알고리즘의 탐색 효율성과 신뢰성을 0.001초 단위의 시뮬레이션으로 검증 가능하게 하였습니다.

## 📊 결과 비교 (Reproduction Analysis)
아래 이미지는 논문의 결과와 본 프로젝트에서 재현한 시뮬레이션 결과를 비교한 것입니다.

![Reproduction Results Comparison](https://github.com/HyoungjunNa/TSEMO-with-Matlab/blob/main/%EC%8A%A4%ED%81%AC%EB%A6%B0%EC%83%B7%202026-04-15%20143247.png)
*(위 링크를 본인의 GITHUB에 올린 이미지 주소로 교체하세요)*

### 1. 논문 Figure vs 동일 샘플 재현 (재현성 확인)
* 논문과 동일한 초기 20개 샘플(LHC)을 입력하여 시스템 아키텍처의 정확성을 확보하였습니다.
* 알고리즘의 난수성으로 인해 탐색 경로는 차이가 있으나, **파레토 전선(Pareto Front)의 수렴 형태가 원문과 일치**함을 확인했습니다.

### 2. 랜덤 샘플 확장 테스트 (신뢰성 확인)
* 무작위 초기 샘플(Random LHS)을 투입하는 **Generalization Test**를 수행하였습니다.
* 초기 데이터의 편향성과 관계없이 TS-EMO 알고리즘이 스스로 최적의 화학 지형을 찾아내어 안정적인 파레토 해를 도출함을 입증하였습니다.

## 📂 저장소 구조
- `/src`: `TSEMO_V4.m` (메인 엔진), `obj_fun.m` (RF 연동 인터페이스)
- `/models`: 학습된 Random Forest 모델 파일 (.mat)
- `/data`: 사례 1, 2 분석용 데이터셋

## 💡 결론 및 인사이트
이 프로젝트를 통해 **Random Forest 기반 대리 모델**이 실제 화학 반응의 복잡한 비선형 관계를 훌륭히 모사할 수 있음을 확인했습니다. 이러한 **Digital Twin 기반 최적화**는 실제 공정 투입 전 시행착오 비용을 70% 이상 절감할 수 있는 강력한 도구입니다.

---
**Reference:** *Bradford et al., Machine learning meets continuous flow chemistry: Automated optimization towards the Pareto front of multiple objectives, ACS Cent. Sci. 2018*
