function deconvolution_carotid(flag_carotid, flag_psf_meth, flag_display, filename_out, p, lambda, maximum_iterations)
% PW imaging - deconvolution of two carotid images
% Script used to reproduce the results of Section V.C of the paper "Towards fast non-stationary deconvolution in ultrasound imaging"
disp('********* Deconvolution of the in vivo carotid *********');
%% Load the data
% Add the right path
addpath(genpath('utils'));

% Load the data set
if flag_carotid == 1
    load 'data/L12-50-50mm_caro_5MHz_ol_dte';
else
    load 'data/L12-50-50mm_caro_5MHz_fr_dte';
end
% Create the G_param structure
G_param = h;
G_param.el_width = G_param.Pitch;
G_param.lambda= G_param.Pitch;

% Select region of interest in the data
z_max = 35/1000;
z_min = 5/1000;
ind_min = round(z_min*2/G_param.c0*G_param.fs)+1;
ind_max = round(z_max*2/G_param.c0*G_param.fs);
rawdata = raw_data(ind_min:ind_max,:);

%% Generate the RF image
% Raw data and image grid
G_param.x = (0:G_param.N_active-1)*G_param.Pitch;
G_param.x = G_param.x - G_param.x(end/2);
G_param.z = (ind_min:ind_max)*G_param.c0/2/G_param.fs;

% Image grid
G_param.z_im = G_param.z(1):G_param.lambda/8:G_param.z(end);
G_param.x_im = G_param.x(1):G_param.lambda/3:G_param.x(end);

% Create the DAS operator
G_param.el_width = G_param.Pitch;
disp('******* Build the DAS operator *******')
disp('It may take a long time (several minutes)')
H_das = BuildHprime_PW(G_param);

% DAS image
disp('******* Generate the RF image *******')
rf = reshape(H_das*rawdata(:), [numel(G_param.z_im), numel(G_param.x_im)]);
L = size(rf);

% Envelope image
env_rf = abs(hilbert(rf));

%% Generate the PSF
if flag_psf_meth == 1
    % Load the prestored PSF
    load 'data/rf_psf_pw_L1250_1.mat';
    psf = rf_image;
    
    % Generate the PSF operator
    F = generate_stationary_psf_operator(psf, L);
    
elseif flag_psf_meth == 2
    % Load the estimated PSF
    if flag_carotid == 1
        load 'data/psf_pw_est_carotid_ol.mat';
        psf = psf_est;
    else
        load 'data/psf_pw_est_carotid_fr.mat';
        psf = psf_est;
    end
    % Generate the PSF operator
    F = generate_stationary_psf_operator(psf, L);
    
elseif flag_psf_meth == 3
    % Pulse shape
    impulse = sin(2*pi*G_param.f0*(0:1/G_param.fs:1/G_param.f0));
    impulse_response = impulse .* hanning(length(impulse))';
    excitation = sin(2*pi*G_param.f0*(0:1/G_param.fs:2/G_param.f0));
    pulse = conv(conv(excitation, impulse_response), impulse_response);
    pulse = pulse / max(abs(pulse));
    
    %-- Create the pulse matrix
    pulse_pad = zeros(size(G_param.z));
    pulse_pad(1:numel(pulse)) = pulse;
    pulse_pad = circshift(pulse_pad, -round(numel(pulse)/2));
    K_h = circulant(pulse_pad);
    
    % Generate the proposed PSF operator
    F = generate_proposed_psf_operator(G_param, H_das, K_h);
    
else
    error('Wrong PSF method, please specify a number between 1 and 3');
end

%% lp-based deconvolution
res = lp_deconvolution(p, lambda, maximum_iterations, rf, F);

% Envelope of the TRF image
trf = reshape(res.x, size(rf));
env_trf = abs(hilbert(trf));

if flag_display == 1
    figure
    imagesc(G_param.x_im*1000, G_param.z_im*1000, 20*log10(env_trf / max(env_trf(:))), [-40 0]); colormap gray;
    axis image;
    xlabel('Lateral dimension [mm]');
    ylabel('Depth [mm]')
    title('Deconvolved image')
    figure
    imagesc(G_param.x_im*1000, G_param.z_im*1000, 20*log10(env_rf / max(env_rf(:))), [-40 0]); colormap gray;
    axis image;
    xlabel('Lateral dimension [mm]');
    ylabel('Depth [mm]')
    title('RF image')
end
if not(isempty(filename_out))
    save(filename_out, 'G_param', 'rf', 'trf');
end
end