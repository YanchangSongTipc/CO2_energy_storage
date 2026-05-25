%% config_paths.m
% 跨平台路径配置 (Windows / Ubuntu)
% 提交到 Git — 两台机器共用

function cfg = config_paths()
    if ispc  % Windows
        cfg.REFPROP_LIB = 'D:\Program Files\REFPROP\';
        cfg.MATLAB_BIN  = 'D:\Program Files\matlab\bin\matlab.exe';
        cfg.DATA_DIR    = fullfile(fileparts(mfilename('fullpath')), 'data');
        cfg.OUTPUT_DIR  = fullfile(fileparts(mfilename('fullpath')), 'output_figures');
    elseif isunix  % Ubuntu
        cfg.REFPROP_LIB = '/opt/refprop/';
        cfg.MATLAB_BIN  = '/usr/local/MATLAB/R2024a/bin/matlab';
        cfg.DATA_DIR    = fullfile(fileparts(mfilename('fullpath')), 'data');
        cfg.OUTPUT_DIR  = fullfile(fileparts(mfilename('fullpath')), 'output_figures');
    else
        error('Unsupported OS');
    end
end
