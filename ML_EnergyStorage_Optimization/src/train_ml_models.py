"""
train_ml_models.py
使用生成的热力学仿真数据训练 XGBoost 和神经网络模型
任务1: 预测运行可行域 (二分类: feasible 0/1)
任务2: 预测可行域边界 (回归: W_max_feasible, Q_max_feasible)
"""

import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.metrics import accuracy_score, r2_score, mean_squared_error
from sklearn.preprocessing import StandardScaler
import xgboost as xgb
import pickle
import os

# =========================================================================
# 1. 加载数据
# =========================================================================
data_path = os.path.join('..', 'data', 'training_data.csv')
df = pd.read_csv(data_path)
print(f'数据集: {len(df)} 样本, {df.columns.tolist()}')

# 特征列
feature_cols = ['SOC_heat_pct', 'SOC_gas_pct', 'W_MW', 'Q_MW', 'mode',
                'beta1', 'beta2', 'alpha1', 'alpha2']

X = df[feature_cols].values
y_feasible = df['feasible'].values
y_Wmax = df['W_max_feasible'].values
y_Qmax = df['Q_max_feasible'].values

# 分割训练/测试集
X_train, X_test, yf_train, yf_test, yW_train, yW_test, yQ_train, yQ_test = \
    train_test_split(X, y_feasible, y_Wmax, y_Qmax, test_size=0.2, random_state=42)

print(f'\n训练集: {len(X_train)}, 测试集: {len(X_test)}')
print(f'可行性分布: 正例={yf_train.sum()/len(yf_train)*100:.1f}%')

# =========================================================================
# 2. XGBoost 分类器 — 预测可行域
# =========================================================================
print('\n=== XGBoost: 可行性分类 ===')
xgb_clf = xgb.XGBClassifier(
    n_estimators=200, max_depth=6, learning_rate=0.1,
    subsample=0.8, colsample_bytree=0.8,
    eval_metric='logloss', use_label_encoder=False, random_state=42
)
xgb_clf.fit(X_train, yf_train)

yf_pred = xgb_clf.predict(X_test)
acc = accuracy_score(yf_test, yf_pred)
print(f'测试准确率: {acc*100:.2f}%')

# 特征重要性
importance = xgb_clf.feature_importances_
for name, imp in sorted(zip(feature_cols, importance), key=lambda x: -x[1]):
    print(f'  {name}: {imp:.4f}')

# =========================================================================
# 3. XGBoost 回归器 — 预测可行域边界
# =========================================================================
print('\n=== XGBoost: 可行域边界回归 ===')

# 仅对 feasible 样本训练边界预测
mask_train = yf_train == 1
mask_test = yf_test == 1

xgb_reg_W = xgb.XGBRegressor(n_estimators=150, max_depth=5, learning_rate=0.1, random_state=42)
xgb_reg_W.fit(X_train[mask_train], yW_train[mask_train])
yW_pred = xgb_reg_W.predict(X_test[mask_test])
r2_W = r2_score(yW_test[mask_test], yW_pred)
rmse_W = np.sqrt(mean_squared_error(yW_test[mask_test], yW_pred))
print(f'W_max: R2={r2_W:.4f}, RMSE={rmse_W:.4f} MW')

xgb_reg_Q = xgb.XGBRegressor(n_estimators=150, max_depth=5, learning_rate=0.1, random_state=42)
xgb_reg_Q.fit(X_train[mask_train], yQ_train[mask_train])
yQ_pred = xgb_reg_Q.predict(X_test[mask_test])
r2_Q = r2_score(yQ_test[mask_test], yQ_pred)
rmse_Q = np.sqrt(mean_squared_error(yQ_test[mask_test], yQ_pred))
print(f'Q_max: R2={r2_Q:.4f}, RMSE={rmse_Q:.4f} MW')

# =========================================================================
# 4. 神经网络 (MLP) — 可行性分类
# =========================================================================
print('\n=== 神经网络 (MLP): 可行性分类 ===')
from sklearn.neural_network import MLPClassifier

scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

mlp = MLPClassifier(
    hidden_layer_sizes=(128, 64, 32), activation='relu',
    solver='adam', alpha=0.001, batch_size=256,
    learning_rate='adaptive', max_iter=300, random_state=42
)
mlp.fit(X_train_scaled, yf_train)

yf_pred_mlp = mlp.predict(X_test_scaled)
acc_mlp = accuracy_score(yf_test, yf_pred_mlp)
print(f'MLP 测试准确率: {acc_mlp*100:.2f}%')

# =========================================================================
# 5. 保存模型
# =========================================================================
model_dir = os.path.join('..', 'models')
os.makedirs(model_dir, exist_ok=True)

with open(os.path.join(model_dir, 'xgb_classifier.pkl'), 'wb') as f:
    pickle.dump(xgb_clf, f)
with open(os.path.join(model_dir, 'xgb_reg_Wmax.pkl'), 'wb') as f:
    pickle.dump(xgb_reg_W, f)
with open(os.path.join(model_dir, 'xgb_reg_Qmax.pkl'), 'wb') as f:
    pickle.dump(xgb_reg_Q, f)
with open(os.path.join(model_dir, 'mlp_classifier.pkl'), 'wb') as f:
    pickle.dump(mlp, f)
with open(os.path.join(model_dir, 'scaler.pkl'), 'wb') as f:
    pickle.dump(scaler, f)

print(f'\n模型已保存到 {model_dir}/')

# =========================================================================
# 6. 结果汇总
# =========================================================================
print('\n' + '='*60)
print('  模型训练结果汇总')
print('='*60)
print(f'  {"模型":20s} {"准确率/R2":>10s} {"备注":>20s}')
print('-'*60)
print(f'  {"XGBoost 分类":20s} {acc*100:9.2f}% {"可行性预测":>20s}')
print(f'  {"MLP 分类":20s} {acc_mlp*100:9.2f}% {"可行性预测":>20s}')
print(f'  {"XGBoost W_max回归":20s} {r2_W:9.4f}  {"RMSE="+str(round(rmse_W,3)):>20s}')
print(f'  {"XGBoost Q_max回归":20s} {r2_Q:9.4f}  {"RMSE="+str(round(rmse_Q,3)):>20s}')
print('='*60)
