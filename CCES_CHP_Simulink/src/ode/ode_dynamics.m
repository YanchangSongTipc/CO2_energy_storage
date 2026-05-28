function [dx, W_comp, Q_IC, W_turb, Q_HR, T_heat, mode] = ode_dynamics(t, x)
% HPT + 双罐HTV (充电8h固定, 放电时长可调)
% x(1)=m_HPT [kg], x(2)=V_hot [m³], x(3)=T_tank [K]
persistent lib Fluid T_sat_vec P_sat_vec V_HPT rho_cp T_hot T_cold V_total a_ch a_dis Wc Wt t_chg t_disch

if isempty(lib)
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
    cfg=config_paths(); lib=cfg.REFPROP_LIB; Fluid='CO2';
    V_HPT=6228; T_hot=483; T_cold=298; rho_cp=850*2.5;
    V_total=150*3600*1000/(rho_cp*(T_hot-T_cold));
    T_sat_vec=(260:0.5:304)'; P_sat_vec=zeros(size(T_sat_vec));
    for i=1:length(T_sat_vec)
        P_sat_vec(i)=getFP(lib,'P','T',T_sat_vec(i),'Q',0,Fluid);
    end
    a_ch=2.744; a_dis=4.117; Wc=9.74; Wt=10.12;
    t_chg=8.0; t_disch=4.0;  % 充电8h, 放电4h (可调)
    fprintf('HTV: Th=%.0fK V=%.0fm3 | 充电%.1fh 放电%.1fh\n',T_hot,V_total,t_chg,t_disch);
end

m_HPT=x(1); V_hot=max(0,min(V_total,x(2))); T_tank=x(3);

% HPT压力
Tc=max(260,min(304,T_tank)); Ps=interp1(T_sat_vec,P_sat_vec,Tc,'linear');
rl=getFP(lib,'D','T',Tc,'Q',0,Fluid); rv=getFP(lib,'D','T',Tc,'Q',1,Fluid);
msl=rl*V_HPT; msv=rv*V_HPT;
if m_HPT>=msl,       P_MPa=Ps/1e6+(m_HPT-msl)/msl*1000;
elseif m_HPT>msv*.05, P_MPa=Ps/1e6;
else,                 P_MPa=m_HPT*188.9*T_tank/V_HPT/1e6;
end

% 调度
t_h=mod(t/3600,24);  t_idle=(24-t_chg-t_disch)/2;
if t_h<t_chg; mode=1;
elseif t_h<t_chg+t_idle; mode=0;
elseif t_h<t_chg+t_idle+t_disch; mode=-1;
else; mode=0;
end

P_ok_ch=m_HPT<msl*.995; P_ok_dis=m_HPT>msv*1.05;
Q_ok_ch=V_hot<V_total*.90; Q_ok_dis=V_hot>V_total*.10;
T_heat=T_hot;

if mode==1 && P_ok_ch && Q_ok_ch
    m_dot=a_ch*Wc; dm_HPT=m_dot;
    [~,q_IC_kJ]=charge_per_kg(lib,Fluid);
    Q_IC_MW=q_IC_kJ*m_dot/1000; dV_hot=Q_IC_MW*1000/(rho_cp*(T_hot-T_cold));
    dT_tank=(298-T_tank)/600; W_comp=Wc; Q_IC=Q_IC_MW; W_turb=0; Q_HR=0;
elseif mode==-1 && P_ok_dis && Q_ok_dis
    m_dot=a_dis*Wt; dm_HPT=-m_dot;
    [~,q_HR_kJ]=discharge_per_kg(lib,Fluid,T_tank,T_heat);
    Q_HR_MW=q_HR_kJ*m_dot/1000; dV_hot=-Q_HR_MW*1000/(rho_cp*(T_hot-T_cold));
    dT_tank=-m_dot*3e-5; W_comp=0; Q_IC=0; W_turb=Wt; Q_HR=Q_HR_MW;
else
    dm_HPT=0; dV_hot=0; dT_tank=(298-T_tank)/50000;
    W_comp=0; Q_IC=0; W_turb=0; Q_HR=0;
end
dx=[dm_HPT; dV_hot; dT_tank];
end

function [w_comp,q_IC]=charge_per_kg(lib,Fluid)
persistent wc qic
if isempty(wc)
    eta_c=0.85; h1=getFP(lib,'H','T',298,'P',0.102e6,Fluid);
    s1=getFP(lib,'S','T',298,'P',0.102e6,Fluid);
    h2is=getFP(lib,'H','P',0.90e6,'S',s1,Fluid); h2=h1+(h2is-h1)/eta_c;
    h3=getFP(lib,'H','T',308,'P',0.85e6,Fluid);
    s3=getFP(lib,'S','T',308,'P',0.85e6,Fluid);
    h4is=getFP(lib,'H','P',6.90e6,'S',s3,Fluid); h4=h3+(h4is-h3)/eta_c;
    h5=getFP(lib,'H','T',309,'P',6.85e6,Fluid);
    wc=(h2-h1+h4-h3)/1000; qic=(h2-h3+h4-h5)/1000;
end
w_comp=wc; q_IC=qic;
end

function [w_turb,q_HR]=discharge_per_kg(lib,Fluid,T_tank,T_heat)
    eta_t=0.88; h_hpt=getFP(lib,'H','T',T_tank,'P',6.65e6,Fluid);
    h_t1in=getFP(lib,'H','T',T_heat,'P',6.50e6,Fluid);
    q_pre=(h_t1in-h_hpt)/1000; s1=getFP(lib,'S','T',T_heat,'P',6.50e6,Fluid);
    h1is=getFP(lib,'H','P',0.70e6,'S',s1,Fluid);
    h1out=h_t1in-eta_t*(h_t1in-h1is); w_t1=(h_t1in-h1out)/1000;
    h_t2in=getFP(lib,'H','T',T_heat,'P',0.65e6,Fluid);
    q_re=(h_t2in-h1out)/1000; s2=getFP(lib,'S','T',T_heat,'P',0.65e6,Fluid);
    h2is=getFP(lib,'H','P',0.12e6,'S',s2,Fluid);
    h2out=h_t2in-eta_t*(h_t2in-h2is); w_t2=(h_t2in-h2out)/1000;
    w_turb=w_t1+w_t2; q_HR=q_pre+q_re;
end

function val=getFP(lib,prop,varargin)
    args=[varargin,{1,1,'MASS BASE SI'}]; val=getFluidProperty(lib,prop,args{:});
end
