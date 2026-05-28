function [dx, W_comp, Q_IC, W_turb, Q_HR, T_heat, mode] = ode_dynamics(t, x)
persistent p
if isempty(p)
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
    cfg=config_paths();
    p.lib=cfg.REFPROP_LIB; p.Fluid='CO2';
    p.V_HPT=6228; p.Th=406; p.Tc=298; p.rho_cp=850*2.5;
    p.Vt=150*3600*1000/(p.rho_cp*(p.Th-p.Tc));
    p.ac=2.744; p.ad=4.117; p.Wc=7.60; p.Wt=8.42;
    p.tc=8.0; p.td=4.0;
    p.rl=getFP(p.lib,'D','T',298,'Q',0,p.Fluid);
    p.rv=getFP(p.lib,'D','T',298,'Q',1,p.Fluid);
    p.msl=p.rl*p.V_HPT; p.msv=p.rv*p.V_HPT;
    fprintf('平衡点: Th=%.0fK | Wc=%.1f Wt=%.1f MW | %.0fh/%.0fh\n',p.Th,p.Wc,p.Wt,p.tc,p.td);
end

m=p.rl(1); Vh=max(0,min(p.Vt(1),x(2))); Tt=x(3);  %#ok<NASGU>

% 调度
th=mod(t/3600,24); ti=(24-p.tc-p.td)/2;
if th<p.tc; mode=1; elseif th<p.tc+ti; mode=0; elseif th<p.tc+ti+p.td; mode=-1; else; mode=0; end

% 约束
ok_c=(m<p.msl*.995)&&(Vh<p.Vt*.90);
ok_d=(m>p.msv*1.05)&&(Vh>p.Vt*.10);

if mode==1 && ok_c
    md=p.ac*p.Wc; dm=md;
    [~,qi]=charge_per_kg(p.lib,p.Fluid); Qic=qi*md/1000;
    dV=Qic*1000/(p.rho_cp*(p.Th-p.Tc));
    dT=(298-Tt)/600; Wc=p.Wc; Qi=Qic; Wt=0; Qr=0;
elseif mode==-1 && ok_d
    md=p.ad*p.Wt; dm=-md;
    [~,qr]=discharge_per_kg(p.lib,p.Fluid,Tt,p.Th); Qr=qr*md/1000;
    dV=-Qr*1000/(p.rho_cp*(p.Th-p.Tc));
    dT=-md*3e-5; Wc=0; Qi=0; Wt=p.Wt; Wr=Qr; %#ok<NASGU>
else
    dm=0; dV=0; dT=(298-Tt)/50000; Wc=0; Qi=0; Wt=0; Qr=0;
end
dx=[dm; dV; dT]; W_comp=Wc; Q_IC=Qi; W_turb=Wt; Q_HR=Qr; T_heat=p.Th;
end

function [wc,qi]=charge_per_kg(lib,Fluid)
persistent w q
if isempty(w)
    e=0.85; h1=getFP(lib,'H','T',298,'P',0.102e6,Fluid);
    s1=getFP(lib,'S','T',298,'P',0.102e6,Fluid);
    h2is=getFP(lib,'H','P',0.90e6,'S',s1,Fluid); h2=h1+(h2is-h1)/e;
    h3=getFP(lib,'H','T',308,'P',0.85e6,Fluid);
    s3=getFP(lib,'S','T',308,'P',0.85e6,Fluid);
    h4is=getFP(lib,'H','P',6.90e6,'S',s3,Fluid); h4=h3+(h4is-h3)/e;
    h5=getFP(lib,'H','T',309,'P',6.85e6,Fluid);
    w=(h2-h1+h4-h3)/1000; q=(h2-h3+h4-h5)/1000;
end
wc=w; qi=q;
end

function [wt,qr]=discharge_per_kg(lib,Fluid,Tt,Th)
    e=0.88; hh=getFP(lib,'H','T',Tt,'P',6.65e6,Fluid);
    ht1=getFP(lib,'H','T',Th,'P',6.50e6,Fluid);
    qp=(ht1-hh)/1000; s1=getFP(lib,'S','T',Th,'P',6.50e6,Fluid);
    h1is=getFP(lib,'H','P',0.70e6,'S',s1,Fluid); h1o=ht1-e*(ht1-h1is);
    w1=(ht1-h1o)/1000; ht2=getFP(lib,'H','T',Th,'P',0.65e6,Fluid);
    qr2=(ht2-h1o)/1000; s2=getFP(lib,'S','T',Th,'P',0.65e6,Fluid);
    h2is=getFP(lib,'H','P',0.12e6,'S',s2,Fluid); h2o=ht2-e*(ht2-h2is);
    w2=(ht2-h2o)/1000; wt=w1+w2; qr=qp+qr2;
end

function v=getFP(lib,prop,varargin)
    args=[varargin,{1,1,'MASS BASE SI'}]; v=getFluidProperty(lib,prop,args{:});
end
