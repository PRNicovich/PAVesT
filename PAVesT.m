% PAVesT.m - Photo-Activated Vesicle Tracking
% View and edit parameters for tracking of vesicles in two-channel 
% images with comparison of particle number over time and cross-channel
% nearest-neighbor distances between detected particles.
%
%
% Requires:
% pkfnd
% cntrd
% bpass
% Vector2Colormap
% freezeColors
% Vector2Colormap_setscale
% imreadBFmeta
% imreadBF
% uipickfiles
%
% v02 - 17 Nov 2014 - Export changed to give number of particles histogram 
% and data in .txt fileeven if no PAcenter region is selected.

function PAVesT

% Close out previous windows so no two are open at same time
close(findobj('Tag', 'TIFF viewer'));


scrsz = get(0,'ScreenSize');

Window_size = [150 100 690 690];


fig1 = figure('Name','PAVesT - PhotoActivated Vesicle Tracker', 'Tag', 'TIFF viewer', 'Units', ...
    'normalized','Position',[Window_size(1)/scrsz(3) Window_size(2)/scrsz(4) Window_size(3)/scrsz(3) Window_size(4)/scrsz(4)], ...
    'NumberTitle', 'off', 'MenuBar', 'none', 'Toolbar', 'figure');
set(fig1, 'Color',[0.9 0.9 0.9]);

%%%%%%%%%%%%
% Set up toolbar
hToolbar = findall(fig1,'tag','FigureToolBar');
AllToolHandles = findall(hToolbar);
ToolBarTags = get(AllToolHandles,'Tag');
ToolsToKeep = {'FigureToolBar'; 'Exploration.DataCursor'; 'Exploration.Pan'; 'Exploration.ZoomOut'; 'Exploration.ZoomIn'};
WhichTools = ~ismember(ToolBarTags, ToolsToKeep);
delete(AllToolHandles(WhichTools));



%'Colormap', [1 1 1]);
% Yields figure position in form [left bottom width height].

fig1_size = get(fig1, 'Position');
set(fig1, 'DeleteFcn', @GUI_close_fcn);

bkg_color = [.9 .9 .9];

handles.handles.fig1 = fig1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialize GUI data
handles.Load_file = '';
handles.N_frames = 2;
handles.N_channels = 2; % 1 or 2 for single, double channel data
handles.Primary_channel = 1;
handles.Img_stack = [];
handles.Left_color = 'cyan';
handles.Right_color = 'red';
handles.Load_file = [];
handles.Left_invert = 0;
handles.Right_invert = 0;
handles.scrsz_pixels = get(0, 'ScreenSize');
handles.Autoscale_left = 0;
handles.Autoscale_right = 0;
handles.Min_max_left = [1 255];
handles.Min_max_right = [1 255];
handles.Display_range_left = [0 1];
handles.Display_range_right = [0 1];
handles.Display_range_ROI = [0 1];

handles.ParticleIntensityThresholds = [12 1.8];
handles.peakfindRadius = 15;
handles.centroidRadius = 21;
handles.bpassValues = [2 9];

handles.BackgroundChannel = 1;
handles.BackgroundThreshold = 12;
handles.ErodeDiameter = 10;

handles.CenterChannel = 3;
handles.CenterIntensity = 20;
handles.FindCtrDilateDiameter = 5;

handles.PixelSize = 0.062; 

handles.SelectedFiles = [];
handles.ColorList = jet(20);
handles.ColorList = handles.ColorList(randperm(size(handles.ColorList, 1)), :);


guidata(fig1, handles);

Startup;

    function Startup(varargin)
        
        handles = guidata(fig1);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Define panels.  

        fig1_size_pixels = fig1_size.*scrsz;

        panel_border = fig1_size_pixels(4)/max(fig1_size_pixels);

        butt_panel = uipanel(fig1, 'Units', 'normalized', 'Position', [0 .95, 1, .05], ...
            'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'button_panel');

        ax_panel1 = uipanel(fig1, 'Units', 'normalized', 'Position', [0 .45 .5 .5], ...
            'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'axes_panel1');

        ax_panel2 = uipanel(fig1, 'Units', 'normalized', 'Position', [.5 .45 .5 .5], ...
            'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'axes_panel2');

        slider_panel = uipanel(fig1, 'Units', 'normalized', 'Position', [0 0 1 .45], ...
            'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'slider_panel');

        handles.handles.butt_panel = butt_panel;
        handles.handles.ax_panel1 = ax_panel1;
        handles.handles.ax_panel2 = ax_panel2;
        handles.handles.slider_panel = slider_panel;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Define axes positions


        ax1 = axes('Parent', ax_panel1, 'Position', [0.002 .005 .994 .994]);
        set(ax1, 'Tag', 'Left axis');


        path_here = mfilename('fullpath');
        %disp(path_here);

        % Find logo file

        if isdeployed

                logo_1 = BMIFLogoGenerate;
                fill_image = imagesc(Vector2Colormap(-logo_1,handles.Left_color), 'Parent', ax1);
                set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');


        else
            logo_file = fullfile(fileparts(path_here), 'BMIF_logo.jpg');


            if exist(logo_file, 'file') == 2;

                logo_hold = single(imread(logo_file));
                logo_1 = logo_hold(:,:,1);
                clear logo_hold  
                fill_image = imagesc(Vector2Colormap(-logo_1,handles.Left_color), 'Parent', ax1);
                set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');

            else

                % Dummy data to put into the axes on startup
                z=peaks(1000);
                z = z./max(abs(z(:)));
                fill_image = imshow(z, 'Parent', ax1, 'ColorMap', jet, 'DisplayRange', [min(z(:)) max(z(:))]);
                set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');
                freezeColors(ax1);

            end
        end

        % Get rid of tick labels
        set(ax1, 'xtick', [], 'ytick', [])
        axis image % Freezes axis aspect ratio to that of the initial image - disallows skewing due to figure reshaping.

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        ax2 = axes('Parent', ax_panel2, 'Position', [0.002 .005 .994 .994]);
        set(ax2, 'Tag', 'Axis2');

        if isdeployed

                logo_1 = BMIFLogoGenerate;
                fill_image = imagesc(Vector2Colormap(-logo_1,handles.Right_color), 'Parent', ax2);
                set(fill_image, 'Tag', 'fill_image_right', 'HitTest', 'on');

        else

            if exist(logo_file, 'file') == 2;

                logo_hold = single(imread(logo_file));
                logo_1 = logo_hold(:,:,1);
                clear logo_hold  
                fill_image = imagesc(Vector2Colormap(-logo_1, handles.Right_color), 'Parent', ax2);
                set(fill_image, 'Tag', 'fill_image_right', 'HitTest', 'on');

            else

                % Dummy data to put into the axes on startup
                z=peaks(1000);
                z = z./max(abs(z(:)));
                fill_image = imshow(z, 'Parent', ax2, 'ColorMap', jet, 'DisplayRange', [min(z(:)) max(z(:))]);
                set(fill_image, 'Tag', 'fill_image_right', 'HitTest', 'on');
                freezeColors(ax2);

            end
        end

        % Get rid of tick labels
        set(ax2, 'xtick', [], 'ytick', []);
        axis image % Freezes axis aspect ratio to that of the initial image - disallows skewing due to figure reshaping.

        handles.handles.ax1 = ax1;
        handles.handles.ax2 = ax2;


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Define button positions

        %%%%%%%%%%%%%%%%%%%%%%
        % Top Button panel buttons

        % Button
        Load_out =     uicontrol(butt_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'Load Path',...
                'Position', [0 .05 .1 .9],...
                'Callback', @Load_pts, 'Tag', 'Load Path');

        % Button %%%%% 
        width = .2;
        Image_preferences_out =     uicontrol(butt_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'Image Preferences',...
                'Position', [(1 - width) .05 width .9],...
                'Callback', @Image_prefs, 'Tag', 'Image_prefs');  

        handles.handles.Load_out = Load_out;
        handles.handles.Image_preferences_out = Image_preferences_out;

        %%%%%%%%%%%%%%%%%%%%%%
        % Slider panel buttons

        % Button
%         ROI_finder_out =     uicontrol(slider_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'Backbone Trace',...
%                 'Position', [.01 .05 .1 .45], 'Enable', 'off', ...
%                 'Callback', @ROI_launch, 'Tag', 'ROI_launch');

        % Button
%         Unbind_out =     uicontrol(slider_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'Unbinding Kinetics',...
%                 'Position', [.12 .05 .1 .45], 'Enable', 'off',...
%                 'Callback', @Unbind_launch, 'Tag', 'Unbind_launch');

            % Button
%         ExpFit_out =     uicontrol(slider_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'Fit Exponential Decay',...
%                 'Position', [.23 .05 .1 .45], 'Enable', 'off',...
%                 'Callback', @ExpFit_launch, 'Tag', 'ExpFit_launch');

            % Button
        handles.handles.SaveConfig =     uicontrol(slider_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'Save Config',...
                'Position', [.98 - 2*width - 0.01 .02 width .12], 'Enable', 'off',...
                'Callback', @SaveConfigPush, 'Tag', 'Save_config_button');


        % Button %%%%%
        width = .2;
        handles.handles.RunAnalysis =     uicontrol(slider_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'Run Analysis',...
                'Position', [(.98 - width) .02 width .12], 'Enable', 'off',...
                'Callback', @RunAnalysis, 'Tag', 'RunAnalysisbutton'); 
            
       % Button %%%%%
        width = .2;
        handles.handles.ImportConfig =     uicontrol(slider_panel, 'Units', 'normalized', 'Style', 'pushbutton', 'String', 'Import Config',...
                'Position', [(.98 - 3*width) - 0.02 .02 width .12], 'Enable', 'off',...
                'Callback', @ImportConfig, 'Tag', 'RunAnalysisbutton'); 

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Define text box positions


        Load_text = uicontrol(butt_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position',[.11 .15 .6 .7], 'BackgroundColor', [1 1 1], ...
            'String', 'File', 'Callback', @Load_edit, 'Tag', 'Load_textbox');

        handles.handles.Load_text = Load_text;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Frame Slider


        slider_value = 0;
        slider_step = 1/(handles.N_frames-1);

        slide_hand = uicontrol(slider_panel, 'Style', 'slider', 'Units', 'normalized',...  
            'SliderStep', [slider_step slider_step], 'Min', 0, 'Max', 1, 'Value', slider_value, 'Position', [.01 .90 .85 .05],...
            'Callback', @slider_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'Slider handle');

        slide_listen = addlistener(slide_hand, 'Value', 'PostSet', @slider_listener);

        slide_box = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.88 .88 .1 .1], 'BackgroundColor', [1 1 1], ...
            'String', 'Frame', 'Callback', @edit_call);




        handles.handles.slide_hand = slide_hand;
        handles.handles.slide_box = slide_box;
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Particle Sliders

        handles.handles.Ptcl_slider_text = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Particle Intensity Threshold . . .', 'Position', [.02 .82 .3 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');

        handles.Ptcl_slider_value_left = handles.Min_max_left(1);
        handles.Ptcl_slider_step_left = 1/(handles.Min_max_left(2));

        handles.handles.Ptcl_slide_hand_left = uicontrol(slider_panel, 'Style', 'slider', 'Units', 'normalized',...  
            'SliderStep', [handles.Ptcl_slider_step_left handles.Ptcl_slider_step_left], 'Min', 0, 'Max', 1, ...
            'Value', handles.Ptcl_slider_value_left, 'Position', [.01 .75 .38 .05],...
            'Callback', @Ptcl_slider_call_left, 'BackgroundColor', [.6 .6 .6], 'Tag', 'Slider handle');

        handles.handles.Ptcl_slide_listen_left = addlistener(handles.handles.Ptcl_slide_hand_left, 'Value', 'PostSet', @Ptcl_slider_listener_left);

        handles.handles.Ptcl_slide_box_left = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.4 .73 .08 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.ParticleIntensityThresholds(1)), 'Callback', @Ptcl_slider_edit_call_left);


        %%%%
        
        handles.Ptcl_slider_value_right = handles.Min_max_right(1);
        handles.Ptcl_slider_step_right = 1/(handles.Min_max_right(2));

        handles.handles.Ptcl_slide_hand_right= uicontrol(slider_panel, 'Style', 'slider', 'Units', 'normalized',...  
            'SliderStep', [handles.Ptcl_slider_step_right handles.Ptcl_slider_step_right], 'Min', 0, 'Max', 1, ...
            'Value', handles.Ptcl_slider_value_right, 'Position', [.51 .75 .38 .05],...
            'Callback', @Ptcl_slider_call_right, 'BackgroundColor', [.6 .6 .6], 'Tag', 'Slider handle');

        handles.handles.Ptcl_slide_listen_right = addlistener(handles.handles.Ptcl_slide_hand_right, 'Value', 'PostSet', @Ptcl_slider_listener_right);

        handles.handles.Ptcl_slide_box_right = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.9 .73 .08 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.ParticleIntensityThresholds(2)),...
            'Callback', @Ptcl_slider_edit_call_right);
        
        %%%% Boxes and text
        
         handles.handles.Ptcl_pkfindText(1) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Peakfind Radius :', 'Position', [.02 .635 .2 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        handles.handles.Ptcl_pkfindText(2) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Centroid Search Kernel :', 'Position', [.30 .635 .2 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        handles.handles.Ptcl_pkfindText(3) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Spatial Bandpass Filter :', 'Position', [.64 .635 .2 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');

        handles.handles.Ptcl_pkfindText(4) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', '-', 'Position', [.88 .635 .05 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        handles.handles.Ptcl_Peakfind_box = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.155 .61 .08 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.peakfindRadius), 'Callback', @Ptcl_peakfind_edit_call);
        
        handles.handles.Ptcl_Centroid_box = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.49 .61 .08 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.centroidRadius), 'Callback', @Ptcl_centroid_edit_call);
        
        handles.handles.Ptcl_Bpass_box(1) = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.82 .61 .05 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.bpassValues(1)), 'Callback', @Ptcl_bandpass_edit_call);
        
        handles.handles.Ptcl_Bpass_box(2) = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.9 .61 .05 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.bpassValues(2)), 'Callback', @Ptcl_bandpass_edit_call);


        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Background Parameters

        handles.handles.bkgd_slider_text(1) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Background Intensity . . .', 'Position', [.02 .53 .3 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        
        handles.handles.bkgd_slider_text(2) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Channel :', 'Position', [.01 .45 .3 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        handles.handles.bkgdChannel = uibuttongroup('Parent',slider_panel,...
            'BorderType', 'none', ...
            'Position',[.081 .43 .15 .1], 'BackgroundColor', [.9 .9 .9], ...
            'SelectionChangeFcn', @bkgd_channel_group_change);
        
        handles.handles.bkgdChanButton(1) = uicontrol(handles.handles.bkgdChannel,'Style','toggle','String','1',...
                'Units','normalized',...
                'Position',[0 0 .4 .9]);
            
        handles.handles.bkgdChanButton(2) = uicontrol(handles.handles.bkgdChannel,'Style','toggle','String','2',...
                'Units','normalized',...
                'Position',[.5 0 .4 .9]);
            
        set(handles.handles.bkgdChannel,'SelectedObject', handles.handles.bkgdChanButton(handles.BackgroundChannel));
            
            
        handles.handles.bkgd_slider_text(3) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Intensity :', 'Position', [.235 .45 .2 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');

        handles.bkgd_slider_value = handles.Min_max_left(1);
        handles.bkgd_slider_step = 1/(handles.Min_max_left(2)+1);

        handles.handles.bkgd_slide_hand = uicontrol(slider_panel, 'Style', 'slider', 'Units', 'normalized',...  
            'SliderStep', [handles.bkgd_slider_value handles.bkgd_slider_value], 'Min', 0, 'Max', 1, ...
            'Value', handles.bkgd_slider_value, 'Position', [.31 .45 .38 .05],...
            'Callback', @bkgd_slider_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'Slider handle');

        handles.handles.bkgd_slide_listen = addlistener(handles.handles.bkgd_slide_hand, 'Value', 'PostSet', @bkgd_slider_listener);

        handles.handles.bkgd_slide_box = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.7 .43 .08 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.BackgroundThreshold), ...
            'Callback', @bkgd_slider_edit_call);


        handles.handles.bkgd_slider_text(4) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Erode Diameter :', 'Position', [.79 .45 .2 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        handles.handles.bkgd_dilate_box = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.913 .43 .08 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.ErodeDiameter), 'Callback', @bkgd_erode_dia_call);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Find Center Parameters

        handles.handles.fndCtr_slider_text(1) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Center Intensity . . .', 'Position', [.02 .33 .3 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        
        handles.handles.fndCtr_slider_text(2) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Channel :', 'Position', [.01 .25 .4 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        handles.handles.fndCtrChannel = uibuttongroup('Parent',slider_panel,...
            'BorderType', 'none', ...
            'Position',[.078 .23 .155 .1], 'BackgroundColor', [.9 .9 .9], 'SelectionChangeFcn', @fndCtrChannel_group_change);
        
        handles.handles.fndCtrChanButton(1) = uicontrol(handles.handles.fndCtrChannel,'Style','toggle','String','1',...
                'Units','normalized', 'HandleVisibility', 'off', 'Tag', 'ctrChanBtn1', ...
                'Position',[0 0 .25 .9]);
            
        handles.handles.fndCtrChanButton(2) = uicontrol(handles.handles.fndCtrChannel,'Style','toggle','String','2',...
                'Units','normalized','HandleVisibility', 'off', 'Tag', 'ctrChanBtn2',...
                'Position',[.25 0 .25 .9]);
            
        handles.handles.fndCtrChanButton(3) = uicontrol(handles.handles.fndCtrChannel,'Style','toggle','String','X',...
                'Units','normalized','HandleVisibility', 'off', 'Tag', 'ctrChanBtn3',...
                'Position',[.5 0 .25 .9]);
            
        handles.handles.fndCtrChanButton(4) = uicontrol(handles.handles.fndCtrChannel,'Style','toggle','String','U',...
                'Units','normalized','HandleVisibility', 'off', 'Tag', 'ctrChanBtn4',...
                'Position',[.75 0 .25 .9]);
            
        set(handles.handles.fndCtrChannel,'SelectedObject', handles.handles.fndCtrChanButton(handles.CenterChannel));
            
            
        handles.handles.fndCtr_slider_text(3) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Intensity :', 'Position', [.235 .25 .2 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');

        handles.fndCtr_slider_value = handles.Min_max_left(1);
        handles.fndCtr_slider_step = 1/(handles.Min_max_left(2)+1);

        handles.handles.fndCtr_slide_hand = uicontrol(slider_panel, 'Style', 'slider', 'Units', 'normalized',...  
            'SliderStep', [handles.fndCtr_slider_value handles.fndCtr_slider_value], 'Min', 0, 'Max', 1, ...
            'Value', handles.fndCtr_slider_value, 'Position', [.31 .25 .38 .05],...
            'Callback', @fndCtr_slider_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'Slider handle');

        handles.handles.fndCtr_slide_listen = addlistener(handles.handles.fndCtr_slide_hand, 'Value', 'PostSet', @fndCtr_slider_listener);

        handles.handles.fndCtr_slide_box = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.7 .23 .08 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.CenterIntensity), 'Callback', @fndCtr_slider_edit_call);


        handles.handles.fndCtr_slider_text(4) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Dilate Diameter :', 'Position', [.79 .25 .2 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        handles.handles.fndCtr_Erode_box = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.913 .23 .08 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.FindCtrDilateDiameter), 'Callback', @fndCtr_erode_dia_call);
        
        %%%% Pixel Size
        
        handles.handles.pixelSizeText(1) = uicontrol(slider_panel, 'Style', 'text', 'Units', 'normalized',...
            'String', 'Pixel Size (um) :', 'Position', [.036 .096 .2 .05], 'BackgroundColor', [.9 .9 .9], ...
            'HorizontalAlignment', 'left');
        
        handles.handles.pixelSizeBox = uicontrol(slider_panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [.159 .08 .12 .1], 'BackgroundColor', [1 1 1], ...
            'String', num2str(handles.PixelSize), 'Callback', @editPixelSizecall);
        
        set(findobj('Parent', slider_panel, 'Type', 'uicontrol'), 'Enable', 'off');
        set(handles.handles.ImportConfig, 'Enable', 'on');
        guidata(fig1, handles);
    end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Callback functions

%%%%%%%%%%%%%%%%%%%%%%
% Frame slider update functions

    function slider_call(varargin)
        
%         handles = guidata(findobj('Tag', 'TIFF viewer'));
% 
%         set(slide_box, 'String', (1 + round((handles.N_frames - 1)*(get(slide_hand, 'Value')))));
%         
%         Display_images_in_axes;

        % handled by listener
        
        
    end

    function slider_listener(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        set(handles.handles.slide_box, 'String', (1 + round((handles.N_frames - 1)*(get(handles.handles.slide_hand, 'Value')))));
        
        Display_images_in_axes;
%         displayBkgdThresholdBndry;
        calculateDetectedParticles('both');
        
    end

    function edit_call(varargin)
        
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        slide_string = str2num(get(handles.handles.slide_box, 'String'));
        
        % Make sure the string fed is actually a string
        
        if length(slide_string) ~= 1
            slide_set = get(handles.handles.slide_hand, 'Value');
            slide_str2 = round(1+slide_set*(handles.N_frames-1));
            set(handles.handles.slide_box, 'String', slide_str2);
            
        else
        
            slide_set = ((slide_string - 1)/(handles.N_frames - 1));
            slide_range = [get(handles.handles.slide_hand, 'Min') get(handles.handles.slide_hand, 'Max')];

            if slide_set > slide_range(2)

                slide_set = slide_range(2);
                slide_str2 = 1+slide_range(2)*(handles.N_frames-1);
                set(handles.handles.slide_box, 'String', num2str(slide_str2));

            elseif slide_set < slide_range(1)

                slide_set = slide_range(1);
                slide_str2 = 1+slide_range(1)*(handles.N_frames-1);
                set(handles.handles.slide_box, 'String', num2str(slide_range(1)));

            end
        
        end
            
        
        set(handles.handles.slide_hand, 'Value', slide_set);
        
        Display_images_in_axes;
%         displayBkgdThresholdBndry;
        calculateDetectedParticles('both');
        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Particle thresholds uicontrol objects

    function Ptcl_slider_call_left(varargin)
        
        % Listener fixes this
        
    end

    function Ptcl_slider_listener_left(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        set(handles.handles.Ptcl_slide_box_left, 'String', num2str(round(100*get(handles.handles.Ptcl_slide_hand_left, 'Value'))/100));
        handles.ParticleIntensityThresholds(1) = round(100*get(handles.handles.Ptcl_slide_hand_left, 'Value'))/100;
        
        guidata(handles.handles.fig1, handles);
        
        calculateDetectedParticles('left');
        
    end

    function Ptcl_slider_edit_call_left(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));

        inputVal = get(varargin{1}, 'String');
        
        if all(isstrprop(inputVal, 'digit') | isstrprop(inputVal, 'punct')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero
            % Keep value 
            handles.ParticleIntensityThresholds(1) = round(100*str2double(inputVal))/100;
        else
            % Revert and set box to match old value
%             disp('revert')
            set(handles.handles.Ptcl_slide_box_left, 'String', sprintf('%.2f', handles.ParticleIntensityThresholds(1)));
        end
        
        guidata(handles.handles.fig1, handles);
        calculateDetectedParticles('left');
        
    end

    function Ptcl_slider_call_right(varargin)
        
        % Listener fixes this
        
    end

    function Ptcl_slider_listener_right(varargin)
        
       handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        set(handles.handles.Ptcl_slide_box_right, 'String', num2str(round(100*get(handles.handles.Ptcl_slide_hand_right, 'Value'))/100));
        handles.ParticleIntensityThresholds(2) = round(100*get(handles.handles.Ptcl_slide_hand_right, 'Value'))/100;
        
        guidata(handles.handles.fig1, handles);
        
        calculateDetectedParticles('right');
        
    end

    function Ptcl_slider_edit_call_right(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));

        inputVal = get(varargin{1}, 'String');
        
        if all(isstrprop(inputVal, 'digit') | isstrprop(inputVal, 'punct')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero
            % Keep value 
            handles.ParticleIntensityThresholds(2) = round(100*str2double(inputVal))/100;
        else
            % Revert and set box to match old value
            set(handles.handles.Ptcl_slide_box_right, 'String', sprintf('%.2f', handles.ParticleIntensityThresholds(2)));
        end
        
        guidata(handles.handles.fig1, handles);
        calculateDetectedParticles('right');
        
    end

    function Ptcl_peakfind_edit_call(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));

        inputVal = get(varargin{1}, 'String');
        
        if all(isstrprop(inputVal, 'digit')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero
            % Keep value 
            handles.peakfindRadius = str2double(inputVal);
        else
            % Revert and set box to match old value
            set(handles.handles.Ptcl_Peakfind_box, 'String', num2str(handles.peakfindRadius));
        end
        
        guidata(handles.handles.fig1, handles);

        BandpassImageStack;
        calculateDetectedParticles('both');
        
    end

    function Ptcl_centroid_edit_call(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));

        inputVal = get(varargin{1}, 'String');
        
        if all(isstrprop(inputVal, 'digit')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero
            % Keep value 
            handles.centroidRadius = str2double(inputVal);
        else
            % Revert and set box to match old value
            set(handles.handles.Ptcl_Centroid_box, 'String', num2str(handles.centroidRadius));
        end
        
        guidata(handles.handles.fig1, handles);

        BandpassImageStack;
        calculateDetectedParticles('both');
        
    end

    function Ptcl_bandpass_edit_call(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        
        set(handles.handles.fig1, 'Pointer', 'watch');
        drawnow;
        whichBox = (handles.handles.Ptcl_Bpass_box == varargin{1});
        
        inputVal = get(varargin{1}, 'String');
        
        if all(isstrprop(inputVal, 'digit')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero
            % Keep value 
            handles.bpassValues(whichBox) = str2double(inputVal);
        else
            % Revert and set box to match old value
            set(handles.handles.Ptcl_Bpass_box, 'String', num2str(handles.bpassValues(whichBox)));
        end
        
        guidata(handles.handles.fig1, handles);

        BandpassImageStack;
        calculateDetectedParticles('both');
        set(handles.handles.fig1, 'Pointer', 'arrow');
        drawnow;
        
        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Background thresholds uicontrol objects

    function bkgd_channel_group_change(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        handles.BackgroundChannel = find(get(handles.handles.bkgdChannel, 'SelectedObject') == flipud(get(handles.handles.bkgdChannel, 'Children')));
        guidata(handles.handles.fig1, handles);
        displayBkgdThresholdBndry;
        calculateDetectedParticles('both');
    end

    function bkgd_slider_call(varargin)
        
       % listener handled
        
    end

    function bkgd_slider_listener(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
               
        set(handles.handles.bkgd_slide_box, 'String', num2str(round(get(handles.handles.bkgd_slide_hand, 'Value'))));
        handles.BackgroundThreshold = round(get(handles.handles.bkgd_slide_hand, 'Value'));
        guidata(handles.handles.fig1, handles);
        displayBkgdThresholdBndry;
        calculateDetectedParticles('both');
    end

    function bkgd_slider_edit_call(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        inputVal = (get(handles.handles.bkgd_slide_box, 'String'));
        
        if all(isstrprop(inputVal, 'digit')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero, so change slider to
            % match
            set(handles.handles.bkgd_slide_hand, 'Value', round(str2double(inputVal)));
            handles.BackgroundThreshold = str2double(inputVal);
        else
            % Revert and set box to match slider
            set(handles.handles.bkgd_slide_box, 'String', num2str(round(get(handles.handles.bkgd_slide_hand, 'Value'))));
        end
            
        guidata(handles.handles.fig1, handles);
        displayBkgdThresholdBndry;
        calculateDetectedParticles('both');
        
    end

    function bkgd_erode_dia_call(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        inputVal = (get(handles.handles.bkgd_dilate_box, 'String'));
        
        if all(isstrprop(inputVal, 'digit')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero
            % Keep value 
            handles.ErodeDiameter = str2double(inputVal);
        else
            % Revert and set box to match old value
            set(handles.handles.bkgd_dilate_box, 'String', num2str(handles.ErodeDiameter));
        end
        
        guidata(handles.handles.fig1, handles);
            
        displayBkgdThresholdBndry;
        calculateDetectedParticles('both');
        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Center intensity uicontrol objects

    function fndCtrChannel_group_change(varargin)
        
        switch get(varargin{2}.NewValue, 'String')
            case '1'
                
%                 disp('Channel 1 for center data')
                set(handles.handles.fndCtr_slide_hand, 'Enable', 'on')
                set(handles.handles.fndCtr_slide_box, 'Enable', 'on')
                set(handles.handles.fndCtr_Erode_box, 'Enable', 'on')
                handles.CenterChannel = 1;
                handles.UserDefinedCenterROIs = {};
                
            case '2' 
                
%                 disp('Channel 2 for center data')
                set(handles.handles.fndCtr_slide_hand, 'Enable', 'on')
                set(handles.handles.fndCtr_slide_box, 'Enable', 'on')
                set(handles.handles.fndCtr_Erode_box, 'Enable', 'on')
                handles.CenterChannel = 2;
                handles.UserDefinedCenterROIs = {};
                
            case 'X' 
                
%                 disp('Omit center channel analysis')
                set(handles.handles.fndCtr_slide_hand, 'Enable', 'off')
                set(handles.handles.fndCtr_slide_box, 'Enable', 'off')
                set(handles.handles.fndCtr_Erode_box, 'Enable', 'off')
                handles.CenterChannel = 3;
                
                delete(findobj('Parent', handles.handles.ax1, 'Type', 'line', 'Color', 'm'));
                delete(findobj('Parent', handles.handles.ax2, 'Type', 'line', 'Color', 'm'));
                handles.UserDefinedCenterROIs = {};
                
            case 'U' 
                
                % User-defined center position
                % Need a roiPoly object for each frame

                set(handles.handles.fndCtr_slide_hand, 'Enable', 'off')
                set(handles.handles.fndCtr_slide_box, 'Enable', 'off')
                set(handles.handles.fndCtr_Erode_box, 'Enable', 'off')
                handles.CenterChannel = 4;
                
                delete(findobj('Parent', handles.handles.ax1, 'Type', 'line', 'Color', 'm'));
                delete(findobj('Parent', handles.handles.ax2, 'Type', 'line', 'Color', 'm'));
                
                guidata(findobj('Tag', 'TIFF viewer'), handles);
                
                setUpUserDefinedCenterROIs();
                
                
        end
        guidata(findobj('Tag', 'TIFF viewer'), handles);
        
        if handles.CenterChannel ~= 3
            
            delete(findobj('parent', handles.handles.ax1, 'tag', 'impoly'));
        
            displayCenterThreshold
            
        end
    end

    function fndCtr_slider_call(varargin)
        
%       disp('slider call')
        
    end

    function fndCtr_slider_listener(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        set(handles.handles.fndCtr_slide_box, 'String', num2str(round(get(handles.handles.fndCtr_slide_hand, 'Value'))));
        handles.CenterIntensity = round(get(handles.handles.fndCtr_slide_hand, 'Value'));
        
        guidata(handles.handles.fig1, handles);
        
        displayCenterThreshold;
        
    end

    function fndCtr_slider_edit_call(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        inputVal = (get(handles.handles.fndCtr_slide_box, 'String'));
        
        if all(isstrprop(inputVal, 'digit')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero, so change slider to
            % match
            set(handles.handles.fndCtr_slide_hand, 'Value', round(str2double(inputVal)));
            handles.CenterIntensity = str2double(inputVal);
        else
            % Revert and set box to match slider
            set(handles.handles.fndCtr_slide_box, 'String', num2str(round(get(handles.handles.fndCtr_slide_hand, 'Value'))));
        end
        
        guidata(handles.handles.fig1, handles);
        
        displayCenterThreshold;
        
    end

    function fndCtr_erode_dia_call(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        inputVal = (get(handles.handles.fndCtr_Erode_box, 'String'));
        
        if all(isstrprop(inputVal, 'digit')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero
            % Keep value 
            handles.FindCtrDilateDiameter = str2double(inputVal);
        else
            % Revert and set box to match old value
            set(handles.handles.fndCtr_Erode_box, 'String', num2str(handles.FindCtrDilateDiameter));
        end
        
        guidata(handles.handles.fig1, handles);
            
        displayCenterThreshold;
        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Edit pixel size box

    function editPixelSizecall(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        inputVal = (get(handles.handles.pixelSizeBox, 'String'));
        
        if all(isstrprop(inputVal, 'digit') | isstrprop(inputVal, 'punct')) && (str2double(inputVal) > 0)
            % input string is digits greater than zero
            % Keep value 
            handles.PixelSize = str2double(inputVal);
        else
            % Revert and set box to match old value
            set(handles.handles.pixelSizeBox, 'String', num2str(handles.PixelSize));
        end
        
        guidata(handles.handles.fig1, handles);
        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Import configuration button

    function ImportConfig(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        if ~isempty(handles.Load_file)
            [~, fN] = fileparts(handles.Load_file);
        else
            fN = '';
        end
        
        [filename, pathname] = uigetfile('*.cfg', 'Import config file', strcat(fN, '.cfg'));
        if isequal(filename,0) || isequal(pathname,0)
           % Do nothing - cancel pressed
        else
            
            set(handles.handles.fig1, 'Pointer', 'watch');
            drawnow;
            
            oldName = handles.Load_file;
            
           % Read in config file
           fID = fopen(fullfile(pathname, filename), 'r');
           
           firstLine = textscan(fID, '%s %s', 1, 'Delimiter', '\t');
           handles.Load_file = firstLine{2}{1};
           
           restoffile = textscan(fID, '%s %f %f', 11, 'Delimiter', '\t');
           handles.ParticleIntensityThresholds(1) = restoffile{2}(1);
           handles.ParticleIntensityThresholds(2) = restoffile{3}(1);
           handles.peakfindRadius = restoffile{2}(2);
           handles.centroidRadius = restoffile{2}(3);
           handles.bpassValues(1) = restoffile{2}(4);
           handles.bpassValues(2) = restoffile{3}(4);
           handles.BackgroundChannel = restoffile{2}(5);
           handles.BackgroundThreshold = restoffile{2}(6);
           handles.ErodeDiameter = restoffile{2}(7);
           handles.CenterChannel = restoffile{2}(8);
           handles.CenterIntensity = restoffile{2}(9);
           handles.FindCtrDilateDiameter = restoffile{2}(10);
           handles.PixelSize = restoffile{2}(11);
           
           fgetl(fID); % skip a line
           
           if handles.CenterChannel == 4
               % read in rest of file for ROIs
               endOfFile = 0;
               
               k = 1;
               
               while endOfFile == 0
                   nextLineX = fgetl(fID);
                   nextLineY = fgetl(fID);
                   
                   if nextLineX ~= -1
                       nextLineX = strsplit(nextLineX, '\t');
                       nextLineY = strsplit(nextLineY, '\t');
                       
                       for m = 2:size(nextLineX, 2)
                           nextLineX{m} = str2double(nextLineX{m});
                           nextLineY{m} = str2double(nextLineY{m});
                       end
                       
                       handles.UserDefinedCenterROIs{k, 1}(:,1) = cell2mat(nextLineX(2:end)');
                       handles.UserDefinedCenterROIs{k, 1}(:,2) = cell2mat(nextLineY(2:end)');
                       k = k+1;
                   else
                       endOfFile = 1;
                   end
               end
               
           end

           fclose(fID);
           
           guidata(handles.handles.fig1, handles);
           
           if ~strcmp(oldName, handles.Load_file); % If new file is different from old file
                
            [pN, fN, extN] = fileparts(handles.Load_file);
            
            DoTheLoadThing(pN, strcat(fN, extN));
           
           else
               
           end
           
           displayBkgdThresholdBndry;
           
           if handles.CenterChannel ~= 3
               
               displayCenterThreshold
               
           else
               
               set(handles.handles.fndCtr_slide_hand, 'Enable', 'off')
               set(handles.handles.fndCtr_slide_box, 'Enable', 'off')
               set(handles.handles.fndCtr_Erode_box, 'Enable', 'off')
               handles.CenterChannel = 3;
               
               delete(findobj('Parent', handles.handles.ax1, 'Type', 'line', 'Color', 'm'));
               delete(findobj('Parent', handles.handles.ax2, 'Type', 'line', 'Color', 'm'));
               
           end
           
           % Go ahead and get initial points detection done
           BandpassImageStack;
           calculateDetectedParticles('both');
                
           set(handles.handles.Ptcl_slide_hand_left, 'Value', (handles.ParticleIntensityThresholds(1)));
           set(handles.handles.Ptcl_slide_box_left, 'String', num2str(handles.ParticleIntensityThresholds(1)));
           
           set(handles.handles.Ptcl_slide_hand_right, 'Value', (handles.ParticleIntensityThresholds(2)));
           set(handles.handles.Ptcl_slide_box_right, 'String', num2str(handles.ParticleIntensityThresholds(2)));
           
           set(handles.handles.Ptcl_Peakfind_box, 'String', num2str(handles.peakfindRadius));
           set(handles.handles.Ptcl_Centroid_box, 'String', num2str(handles.centroidRadius));
           
           set(handles.handles.Ptcl_Bpass_box(1), 'String', num2str(handles.bpassValues(1)));
           set(handles.handles.Ptcl_Bpass_box(2), 'String', num2str(handles.bpassValues(2)));
           
           set(handles.handles.bkgdChannel, 'SelectedObject', handles.handles.bkgdChanButton(handles.BackgroundChannel));
           set(handles.handles.bkgd_slide_hand, 'Value', handles.BackgroundThreshold);
           set(handles.handles.bkgd_slide_box, 'String', num2str(handles.BackgroundThreshold));
           set(handles.handles.bkgd_dilate_box, 'String', num2str(handles.ErodeDiameter));
           
           set(handles.handles.fndCtrChannel, 'SelectedObject', handles.handles.fndCtrChanButton(handles.CenterChannel));
           set(handles.handles.fndCtr_slide_hand, 'Value', handles.CenterIntensity);
           set(handles.handles.fndCtr_slide_box, 'String', num2str(handles.CenterIntensity));
           set(handles.handles.fndCtr_Erode_box, 'String', num2str(handles.FindCtrDilateDiameter));
           
           set(handles.handles.pixelSizeBox, 'String', num2str(handles.PixelSize));
           
           drawnow;
           

           
           set(handles.handles.fig1, 'pointer', 'arrow');
           
        end
        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Save configuration button

    function SaveConfigPush(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        [~, fN] = fileparts(handles.Load_file);
        
        [filename, pathname] = uiputfile('*.cfg', 'Save config file', strcat(fN, '.cfg'));
        if isequal(filename,0) || isequal(pathname,0)
           % Do nothing - cancel pressed
        else
           % Write config file
           fID = fopen(fullfile(pathname, filename), 'w+');
           fprintf(fID, 'File Path :\t%s\n', handles.Load_file);
           fprintf(fID, 'Peakfind Intensity Threshold :\t%.2f\t%.2f\n', handles.ParticleIntensityThresholds(1), handles.ParticleIntensityThresholds(2));
           fprintf(fID, 'Peakfind Radius : \t%.0f\n', handles.peakfindRadius);
           fprintf(fID, 'Peakfind Centroid Kernel : \t%.0f\n', handles.centroidRadius);
           fprintf(fID, 'Peakfind Bandpass Filter :\t%.0f\t%.0f\n', handles.bpassValues(1), handles.bpassValues(2));
           fprintf(fID, 'Background Channel : \t%.0f\n', handles.BackgroundChannel);
           fprintf(fID, 'Background Threshold : \t%.0f\n', handles.BackgroundThreshold);
           fprintf(fID, 'Background Erode Diameter : \t%.0f\n', handles.ErodeDiameter);
           fprintf(fID, 'Center Threshold Channel : \t%.0f\n', handles.CenterChannel);
           fprintf(fID, 'Center Threshold Intensity : \t%.0f\n', handles.CenterIntensity);
           fprintf(fID, 'Center Threshold Dilate Diameter : \t%.0f\n', handles.FindCtrDilateDiameter);
           fprintf(fID, 'Pixel Size : \t%.8f\n', handles.PixelSize);
           
           % Long part to save all of the center polygons
           if handles.CenterChannel == 4
              for k = 1:handles.N_frames
                  roiString = repmat('\t%.1f', 1, size(handles.UserDefinedCenterROIs{k}, 1));
                  roiString = strcat('ROI_%d,%s', roiString, '\n');
                  fprintf(fID, roiString, k, 'x',  handles.UserDefinedCenterROIs{k}(:,1));
                  fprintf(fID, roiString, k, 'y',  handles.UserDefinedCenterROIs{k}(:,2));
              end
           end
           
           fclose(fID);
        end
        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Run analysis button

    function RunAnalysis(varargin)
        
        if ~isempty(findobj('Tag', 'RunAnalysisFig'))
        
            uistack(findobj('Tag', 'RunAnalysisFig'), 'top');
            
        else
            
            %fig1 = findobj('Tag', 'TIFF viewer');
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            mf_post = get(findobj('Tag', 'TIFF viewer'), 'Position').*([handles.scrsz_pixels(3) handles.scrsz_pixels(4) handles.scrsz_pixels(3) handles.scrsz_pixels(4)]);      
            fig2_size = [230 300];
            fig2_position = [(mf_post(1) + (mf_post(3) - fig2_size(1))/2) (mf_post(2) + (mf_post(4) - fig2_size(2))/2)];
            handles.handles.fig3 = figure('Name','Run Analysis', 'Tag', 'RunAnalysisFig', 'Units', 'pixels',...
                'Position',[fig2_position fig2_size], 'NumberTitle', 'off', 'Toolbar', 'none', 'Menu', 'none');
            set(handles.handles.fig3, 'Color',[0.9 0.9 0.9]);
            
            
            folderIcon = get(findall(handles.handles.fig3, 'tag', 'Standard.FileOpen'), 'CData');
%             set(handles.handles.fig3, 'Toolbar', 'none');

            handles.handles.RunAnalysisButton = uicontrol('Style', 'pushbutton', 'Units', 'normalized', ...
            'Position', [0.7433    0.0205    0.2267    0.0895], 'Parent', handles.handles.fig3,...
            'Callback', @RunAnalysisPush, 'String', 'Run!');
        
             handles.handles.RunAnalysisText(1) = uicontrol(handles.handles.fig3, 'Style', 'text', 'Units', 'normalized', ...
            'Position',[-0.0515    0.9025    0.5929    0.0700], ...
            'String', 'Add Configurations : ', 'BackgroundColor', [.9 .9 .9]);
        
             handles.handles.RunAnalysisText(2) = uicontrol(handles.handles.fig3, 'Style', 'text', 'Units', 'normalized', ...
            'Position',[0.4739    0.75    0.2978    0.06], ...
            'String', 'Create GIF : ', 'BackgroundColor', [.9 .9 .9]);
        
            handles.handles.RunAnalysisText(3) = uicontrol(handles.handles.fig3, 'Style', 'text', 'Units', 'normalized', ...
            'Position',[0.3000    0.66    0.4756    0.06], ...
            'String', 'Save Image Series : ', 'BackgroundColor', [.9 .9 .9]);
        
             handles.handles.RunAnalysisText(4) = uicontrol(handles.handles.fig3, 'Style', 'text', 'Units', 'normalized', ...
            'Position',[0.2609    0.57   0.5100    0.06], ...
            'String', 'Save Histogram Data : ', 'BackgroundColor', [.9 .9 .9]);
        
            handles.handles.RunAnalysisText(10) = uicontrol(handles.handles.fig3, 'Style', 'text', 'Units', 'normalized', ...
            'Position',[0.1504   0.48   0.6448    0.06], ...
            'String', 'Split Center from Interior :', 'BackgroundColor', [.9 .9 .9]);
        
             handles.handles.RunAnalysisText(5) = uicontrol(handles.handles.fig3, 'Style', 'text', 'Units', 'normalized', ...
            'Position',[0.1304   0.39    0.6448    0.06], ...
            'String', 'Include Randomized Points : ', 'BackgroundColor', [.9 .9 .9]);
        
             handles.handles.RunAnalysisText(6) = uicontrol(handles.handles.fig3, 'Style', 'text', 'Units', 'normalized', ...
            'Position',[0.1370    0.2167    0.2761    0.0933], ...
            'String', 'Histogram Bins (nm) : ', 'BackgroundColor', [.9 .9 .9]);
        
             handles.handles.RunAnalysisText(7) = uicontrol(handles.handles.fig3, 'Style', 'text', 'Units', 'normalized', ...
            'Position',[0.43    0.29    0.16    0.0700], ...
            'String', 'Start', 'BackgroundColor', [.9 .9 .9]);
        
             handles.handles.RunAnalysisText(8) = uicontrol(handles.handles.fig3, 'Style', 'text', 'Units', 'normalized', ...
            'Position',[0.63    0.29    0.16    0.0700], ...
            'String', 'Step', 'BackgroundColor', [.9 .9 .9]);
        
             handles.handles.RunAnalysisText(9) = uicontrol(handles.handles.fig3, 'Style', 'text', 'Units', 'normalized', ...
            'Position',[0.822   0.29    0.16    0.0700], ...
            'String', 'End', 'BackgroundColor', [.9 .9 .9]);
        

            
            handles.handles.InputPathButton = uicontrol('Style', 'pushbutton', 'Units', 'normalized', ...
            'Position', [0.8043    0.8333    0.1739    0.0842], 'Parent', handles.handles.fig3,...
            'CData', folderIcon, 'Callback', @InputPathPush, 'FontSize', 10);

            handles.handles.InputPathText = uicontrol(handles.handles.fig3, 'Style', 'edit', 'Units', 'normalized', ...
            'Position',[0.0357    0.8367    0.7400    0.0767], ...
            'BackgroundColor', [1 1 1], 'Enable', 'on', 'Visible', 'on', ...
            'String', '---', 'Callback', @InputPathEdit);

            handles.handles.GIFCheck = uicontrol(handles.handles.fig3, 'Style', 'checkbox', 'Units', 'normalized', ...
            'Position',[0.8587    0.7500    0.0667    0.0625], ...
            'BackgroundColor', [.9 .9 .9], 'Enable', 'on', 'Visible', 'on', ...
            'Value', 1);

            handles.handles.ExportImageSeries = uicontrol(handles.handles.fig3, 'Style', 'checkbox', 'Units', 'normalized', ...
            'Position',[0.8587    0.66    0.0667    0.0625], ...
             'BackgroundColor', [.9 .9 .9], 'Enable', 'on', 'Visible', 'on', ...
            'Value', 0);
        
             handles.handles.ExportHistData = uicontrol(handles.handles.fig3, 'Style', 'checkbox', 'Units', 'normalized', ...
            'Position',[0.8587    0.57    0.0667    0.0625], ...
             'BackgroundColor', [.9 .9 .9], 'Enable', 'on', 'Visible', 'on', ...
            'Value', 1);
        
            handles.handles.SplitCenter = uicontrol(handles.handles.fig3, 'Style', 'checkbox', 'Units', 'normalized', ...
            'Position',[0.8587    0.48    0.0667    0.0625], ...
             'BackgroundColor', [.9 .9 .9], 'Enable', 'on', 'Visible', 'on', ...
            'Value', 1);
        
             handles.handles.IncludeRandPts = uicontrol(handles.handles.fig3, 'Style', 'checkbox', 'Units', 'normalized', ...
            'Position',[0.8587    0.39    0.0667    0.0625], ...
             'BackgroundColor', [.9 .9 .9], 'Enable', 'on', 'Visible', 'on', ...
            'Value', 1);
        
            handles.handles.HistogramRange(1) = uicontrol(handles.handles.fig3, 'Style', 'edit', 'Units', 'normalized', ...
            'Position',[0.44    0.2138    0.1596    0.0954], ...
             'BackgroundColor', [1 1 1], 'Enable', 'on', 'Visible', 'on', ...
            'String', '0');
        
            handles.handles.HistogramRange(2) = uicontrol(handles.handles.fig3, 'Style', 'edit', 'Units', 'normalized', ...
            'Position',[0.63   0.2138    0.1596    0.0954], ...
             'BackgroundColor', [1 1 1], 'Enable', 'on', 'Visible', 'on', ...
            'String', '20');
        
            handles.handles.HistogramRange(3) = uicontrol(handles.handles.fig3, 'Style', 'edit', 'Units', 'normalized', ...
            'Position',[0.8200    0.2138    0.1596    0.0954], ...
             'BackgroundColor', [1 1 1], 'Enable', 'on', 'Visible', 'on', ...
            'String', '1500');
        
        
            set(handles.handles.RunAnalysisButton, 'Enable', 'off');
        
            guidata(handles.handles.fig1, handles);
        end
        
        
        function InputPathPush(varargin)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));

            selectFiles = uipickfiles('FilterSpec', pwd, 'Type', { '*.cfg',   'Config Files' }, 'Append', handles.SelectedFiles);

                if iscell(selectFiles)
                    handles.SelectedFiles = selectFiles;

                    set(handles.handles.RunAnalysisButton, 'Enable', 'on');
                    set(handles.handles.InputPathText, 'String', sprintf('Process %d Files', length(handles.SelectedFiles)));

                    guidata(handles.handles.fig1, handles);
                end

        end
            
        
        function RunAnalysisPush(varargin)
            
            set(handles.handles.fig3, 'Pointer', 'watch');
            set(findobj('Parent', handles.handles.fig3, 'type', 'uicontrol'), 'enable', 'off');
            drawnow;
            
            IncludeRandomPoints = get(handles.handles.IncludeRandPts, 'Value');
            if length(handles.SelectedFiles) > size(handles.ColorList, 1)/2
                handles.ColorList = jet(length(handles.SelectedFiles)*2);
                handles.ColorList = handles.ColorList(randperm(size(handles.ColorList, 1)), :);
            end
            
            % Actually do the necessary analysis
            
            histcList = str2double(get(handles.handles.HistogramRange(1), 'String')):str2double(get(handles.handles.HistogramRange(2), 'String')):str2double(get(handles.handles.HistogramRange(3), 'String'));
            
            histcList = [histcList histcList(end) + diff(histcList(1:2))];
            
            histMatrix = zeros(numel(histcList)-1, 2*length(handles.SelectedFiles)+1);
            histMatrix(:,1) = histcList(1:(end-1));
            
            histMatrixSameChannel = histMatrix;
            
            if handles.handles.SplitCenter.Value()
                histMatrixSplit = zeros(numel(histcList)-1, 4*length(handles.SelectedFiles)+1);
                histMatrixSplitSameChannel = zeros(numel(histcList)-1, 4*length(handles.SelectedFiles)+1);
                
                histMatrixSplit(:,1) = histcList(1:(end-1));
                histMatrixSplitSameChannel(:,1) = histcList(1:(end-1));
            end

            if IncludeRandomPoints
                RandomHistMatrix = histMatrix;
                RandomHistMatrixSameChannel = histMatrix;
                
                if handles.handles.SplitCenter.Value()
                    RandomHistMatrixSplit = zeros(numel(histcList)-1, 4*length(handles.SelectedFiles)+1);
                    RandomHistMatrixSplit(:,1) = histcList(1:(end-1));
                    
                    RandomHistMatrixSplitSameChannel = zeros(numel(histcList)-1, 4*length(handles.SelectedFiles)+1);
                    RandomHistMatrixSplitSameChannel(:,1) = histcList(1:(end-1));
                end
                
            end
            
            InOutParticles = cell(length(handles.SelectedFiles), 1);
            InOutCheck = zeros(length(handles.SelectedFiles), 1);
            
            fileNameArray = cell(length(handles.SelectedFiles), 1);
            
            
            if get(handles.handles.ExportHistData, 'Value') == 1
                    histogramFigure = figure(9);
                    clf(histogramFigure);
                    histAx = axes('Parent', histogramFigure);
                    
                    InOutFigure = figure(10);
                    clf(InOutFigure);
                    InOutAxes = axes('Parent', InOutFigure);
            end
            
            for fN = 1:length(handles.SelectedFiles)
                
                % Read in config file
                
                oldName = handles.Load_file;
                
                [folderPath, fileName, ext] = fileparts(handles.SelectedFiles{fN});
            
               fID = fopen(fullfile(folderPath, strcat(fileName, ext)), 'r');

               firstLine = textscan(fID, '%s %s', 1, 'Delimiter', '\t');
               AnalParam.Load_file = firstLine{2}{1};

               restoffile = textscan(fID, '%s %f %f', 11, 'Delimiter', '\t');
               AnalParam.ParticleIntensityThresholds(1) = restoffile{2}(1);
               AnalParam.ParticleIntensityThresholds(2) = restoffile{3}(1);
               AnalParam.peakfindRadius = restoffile{2}(2);
               AnalParam.centroidRadius = restoffile{2}(3);
               AnalParam.bpassValues(1) = restoffile{2}(4);
               AnalParam.bpassValues(2) = restoffile{3}(4);
               AnalParam.BackgroundChannel = restoffile{2}(5);
               AnalParam.BackgroundThreshold = restoffile{2}(6);
               AnalParam.ErodeDiameter = restoffile{2}(7);
               AnalParam.CenterChannel = restoffile{2}(8);
               AnalParam.CenterIntensity = restoffile{2}(9);
               AnalParam.FindCtrDilateDiameter = restoffile{2}(10);
               AnalParam.PixelSize = restoffile{2}(11);

               
               fgetl(fID); % skip a line
               
               if AnalParam.CenterChannel == 4
                   % read in rest of file for ROIs
                   endOfFile = 0;
                   
                   k = 1;
                   
                   while endOfFile == 0
                       nextLineX = fgetl(fID);
                       nextLineY = fgetl(fID);
                       
                       if nextLineX ~= -1
                           nextLineX = strsplit(nextLineX, '\t');
                           nextLineY = strsplit(nextLineY, '\t');
                           
                           for m = 2:size(nextLineX, 2)
                               nextLineX{m} = str2double(nextLineX{m});
                               nextLineY{m} = str2double(nextLineY{m});
                           end
                           
                           AnalParam.UserDefinedCenterROIs{k, 1}(:,1) = cell2mat(nextLineX(2:end)');
                           AnalParam.UserDefinedCenterROIs{k, 1}(:,2) = cell2mat(nextLineY(2:end)');
                           k = k+1;
                       else
                           endOfFile = 1;
                       end
                   end
                   
               end

               fclose(fID);
               
               
               if ~strcmp(AnalParam.Load_file, oldName);
                   
               	metaData = imreadBFmeta(AnalParam.Load_file);
                dataGreen = imreadBF(AnalParam.Load_file, 1:metaData.zsize, 1:metaData.nframes, 1);
                dataRed = imreadBF(AnalParam.Load_file, 1:metaData.zsize, 1:metaData.nframes, 2);
                
                dataGreen(dataGreen < 0) = dataGreen(dataGreen < 0) + 255;
                dataRed(dataRed < 0) = dataRed(dataRed < 0) + 255;
                
                handles.N_frames = metaData.nframes;
                
               else
                   
                   dataGreen = squeeze(handles.Img_stack(:,:,1,:));
                   dataRed = squeeze(handles.Img_stack(:,:,2,:));
                   
               end
               
               
               
                if get(handles.handles.GIFCheck, 'Value') == 1
                    MakeGif = true;
                    GIFfilename = fullfile(folderPath, strcat(fileName, '_TrackingImage.gif'));
                    gifWindow = figure();
                    gifAxes = axes('Parent', gifWindow);
                else
                    MakeGif = false;
                end
                %%%%%%%%%%%%%%%%%%%%%%%
                % Image series folder
                if get(handles.handles.ExportImageSeries, 'Value') == 1
                    ExportSeries = true;
                    ExportSeriesFolder = strcat(folderPath, '\', fileName, '_ImageSeries');
                    if ~exist(ExportSeriesFolder,'dir')
                        mkdir(ExportSeriesFolder)
                    end
                else
                    ExportSeries = false;
                end
                
                
                fileNameArray{fN} = fileName;
                
                % Do 2d particle tracking here
                postListG = [];
                postListR = [];

                NNdistG = [];
                NNdistR = [];
                
                NNdistGG = [];
                NNdistRR = [];
                
                NNdistGGIn = [];
                NNdistRRIn = [];
                
                NNdistGGOut = [];
                NNdistRROut = [];
                
                NNdistGOut = [];
                NNdistGIn = [];
                
                NNdistROut = [];
                NNdistRIn = [];
                
                bootList_GRIn = [];
                bootList_RGIn = [];
                bootList_GROut = [];
                bootList_RGOut = [];
                
                bootList_GGIn = [];
                bootList_RRIn = [];
                bootList_GGOut = [];
                bootList_RROut = [];
                
                InOutParticles{fN} = zeros((handles.N_frames-1), 5);

                    for k = 1:(handles.N_frames-1)
                        dataHereG = dataGreen(:,:,k);
                        
                        dataHereR = dataRed(:,:,k);

                        % Find cell border
                        
                        if AnalParam.BackgroundChannel == 1
                            gT = (dataHereG > (AnalParam.BackgroundThreshold));
                        elseif AnalParam.BackgroundChannel == 2
                            gT = (dataHereR > (AnalParam.BackgroundThreshold));
                        end
                        
                        gT = imfill(gT, 'holes');
                        gT = bwmorph(gT, 'open');
                        regs = regionprops(gT, 'area', 'PixelIdxList');
                        rA = vertcat(regs.Area);
                        regs(rA ~= max(rA)) = [];
                        bwImg = false(numel(dataHereG), 1);
                        bwImg(regs.PixelIdxList) = 1;
                        bwImg = reshape(bwImg, size(dataHereG, 1), size(dataHereG, 2));

                        Bo = bwboundaries(bwImg, 'noholes');

                        bwImg = bwmorph(bwImg, 'erode', AnalParam.ErodeDiameter);

                        B = bwboundaries(bwImg, 'noholes');


                        
                        bG = bpass(dataHereG, AnalParam.bpassValues(1), AnalParam.bpassValues(2));
                        pkG = pkfnd(bG, AnalParam.ParticleIntensityThresholds(1), AnalParam.peakfindRadius);

                        inList = zeros(size(pkG, 1), 1);
                        for m = 1:size(pkG, 1)
                            inList(m) = bwImg(pkG(m,2), pkG(m,1));
                        end

                        pkG(inList == 0, :) = [];

                        if ~isempty(pkG)

                            centG = cntrd(dataHereG, pkG, AnalParam.centroidRadius);

                            postListG = [postListG; centG(:,1), centG(:,2), repmat(k, size(centG, 1), 1), ones(size(centG, 1), 1)];

                        end

                        dataHereR = dataRed(:,:,k);
                        dataHereR(dataHereR < 0) = dataHereR(dataHereR<0) + 255;

                        % Red processing
                        bR = bpass(dataHereR, AnalParam.bpassValues(1), AnalParam.bpassValues(2));
                        pkR = pkfnd(bR, AnalParam.ParticleIntensityThresholds(2), AnalParam.peakfindRadius);

                        inList = zeros(size(pkR, 1), 1);
                        for m = 1:size(pkR, 1)
                            inList(m) = bwImg(pkR(m,2), pkR(m,1));
                        end

                        pkR(inList == 0, :) = [];


                        if ~isempty(pkR)

                            centR = cntrd(dataHereR, pkR, AnalParam.centroidRadius);
%                             assignin('base', 'centR', centR);
%                             assignin('base', 'postListR', postListR);
                            postListR = [postListR; centR(:,1), centR(:,2), repmat(k, size(centR, 1), 1), ones(size(centR, 1), 1)];

                        end
                        
                        %%%%%%%%%%%%%
                        % Add in bits for center vs outside segmentation
                        if AnalParam.CenterChannel ~= 3
                            
                            borderImg = bwImg;
                            
                            if ismember(AnalParam.CenterChannel, [1, 2]);
                                ctrVal = AnalParam.CenterIntensity;
                                dilatePixels = AnalParam.FindCtrDilateDiameter;

                                if AnalParam.CenterChannel == 1
                                    gC = (dataHereG > (AnalParam.CenterIntensity));
                                elseif AnalParam.CenterChannel == 2
                                    gC = (dataHereR > (AnalParam.CenterIntensity));
                                end
                                regs = regionprops(gC, 'area', 'PixelIdxList');
                                rA = vertcat(regs.Area);
                                regs(rA ~= max(rA)) = [];
                                ctrImg = false(size(borderImg, 1)*size(borderImg, 2), 1);
                                ctrImg(vertcat(regs.PixelIdxList)) = 1;
                                ctrImg = reshape(ctrImg, size(borderImg, 1), size(borderImg, 2));
                                ctrImg = bwmorph(ctrImg, 'dilate', dilatePixels);

                            elseif AnalParam.CenterChannel == 4
                                
                                borderImg = bwImg;
                                
                                ctrImg = poly2mask(AnalParam.UserDefinedCenterROIs{k}(:,1), ...
                                    AnalParam.UserDefinedCenterROIs{k}(:,2), size(dataGreen, 1), ...
                                    size(dataGreen, 2));
                            end

                            cBo = bwboundaries(ctrImg, 'noholes');

                            ctrMask = borderImg;
                            ctrMask(ctrImg) = 0;

                            cB = bwboundaries(ctrImg, 'noholes');
                            
                            if ~isempty(postListG)
                                pgHere = postListG(postListG(:,3) == k, :);
                                
                                for m = 1:size(pgHere, 1)
                                    pgHere(m,4) = ctrMask((pkG(m,2)), (pkG(m,1)));
                                end
                                
                                postListG(postListG(:,3) == k, :) = pgHere;
                            end
                            
                            if ~isempty(postListR)
                                
                                prHere = postListR(postListR(:,3) == k, :);

                                for m = 1:size(prHere, 1)
                                    prHere(m,4) = ctrMask((pkR(m,2)), (pkR(m,1)));
                                end  
                                
                                postListR(postListR(:,3) == k, :) = prHere;
                            end
                            
   
                            
                        end


                        if MakeGif || ExportSeries
                            C = imfuse(dataHereG, dataHereR,'falsecolor','Scaling','independent','ColorChannels','red-cyan');
                            imshow(C, 'Parent', gifAxes)
                            set(gifAxes, 'NextPlot', 'add');

                            
                            if ~isempty(postListG) 
                                
                                plot(gifAxes, postListG((postListG(:,3)==k & postListG(:,4) == 1), 1), ...
                                    postListG((postListG(:,3)==k & postListG(:,4) == 1), 2), 'cx')
                                plot(gifAxes, postListG((postListG(:,3)==k & postListG(:,4) == 0), 1), ...
                                    postListG((postListG(:,3)==k & postListG(:,4) == 0), 2), 'cs', 'markerfacecolor', 'c', 'MarkerSize', 3)
                            end
                            
                            if ~isempty(postListR)
                                plot(gifAxes, postListR((postListR(:,3)==k & postListR(:,4) == 1), 1), ...
                                    postListR((postListR(:,3)==k & postListR(:,4) == 1), 2), 'rx')
                                plot(gifAxes, postListR((postListR(:,3)==k & postListR(:,4) == 0), 1), ...
                                    postListR((postListR(:,3)==k & postListR(:,4) == 0), 2), 'rs', 'markerfacecolor', 'r', 'MarkerSize', 3)
                            end

                            for m = 1:length(B)
                                plot(gifAxes, B{m}(:,2), B{m}(:,1), 'w')
                            end

                            for m = 1:length(Bo)
                                plot(gifAxes, Bo{m}(:,2), Bo{m}(:,1), 'w:')
                            end
                            
                            if AnalParam.CenterChannel ~= 3
                                for m = 1:length(cB)
                                    plot(gifAxes, cB{m}(:,2), cB{m}(:,1), 'm')
                                end
                                
                                for m = 1:length(cBo)
                                    plot(gifAxes, cBo{m}(:,2), cBo{m}(:,1), 'm:')
                                end
                            end
                            

                            set(gifAxes, 'NextPlot', 'replace');
                            
                            % Finish formatting image
                            title(gca, sprintf('%s Frame %d', fileName, k), 'interpreter', 'none')
                            
                              drawnow
                              frame = getframe(gifWindow);
                              im = frame2im(frame);
                              [imind,cm] = rgb2ind(im,256);
                            
                        end


                        % Capture frame for gif
                        if MakeGif == true

                          if k == 1;
                              imwrite(imind,cm,GIFfilename,'gif', 'Loopcount',inf, 'DelayTime', .2);
                          else
                              imwrite(imind,cm,GIFfilename,'gif','WriteMode','append', 'DelayTime', .2);
                          end
                          
                          
                        end
                        
                        if ExportSeries == true
                           
                           imgFileName = fullfile(ExportSeriesFolder, sprintf('Image_%04d.tif', k));
                           
                           imwrite(imind, cm, imgFileName, 'tiff');                            
                            
                        end
                        
                        if ~isempty(pkG) && ~isempty(pkR)

                            [~, dG] = knnsearch(postListG(postListG(:,3)==k, 1:2), postListR(postListR(:,3)==k, 1:2));
                            NNdistG = [NNdistG; dG];

                            [~, dR] = knnsearch(postListR(postListR(:,3)==k, 1:2), postListG(postListG(:,3)==k, 1:2));
                            NNdistR = [NNdistR; dR];
                            
                            [~, dG] = knnsearch(postListG(postListG(:,3)==k, 1:2), postListG(postListG(:,3)==k, 1:2), 'K', 2);
                            NNdistGG = [NNdistGG; dG(dG > 0)];

                            [~, dR] = knnsearch(postListR(postListR(:,3)==k, 1:2), postListR(postListR(:,3)==k, 1:2), 'K', 2);
                            NNdistRR = [NNdistRR; dR(dR > 0)];
                            
                           
                            if handles.handles.SplitCenter.Value()
                                % Calc NNdistG and NNdistR for inner and
                                % outer regions
                                [~, dG] = knnsearch(postListG(postListG(:,3)==k & postListG(:,4) == 0, 1:2), ...
                                    postListR(postListR(:,3)==k & postListR(:,4) == 0, 1:2));
                                NNdistGOut = [NNdistGOut; dG];
                                
                                [~, dG] = knnsearch(postListG(postListG(:,3)==k & postListG(:,4) == 1, 1:2), ...
                                    postListR(postListR(:,3)==k & postListR(:,4) == 1, 1:2));
                                NNdistGIn = [NNdistGIn; dG];
                                
                                [~, dR] = knnsearch(postListR(postListR(:,3)==k & postListR(:,4) == 1, 1:2), ...
                                    postListG(postListG(:,3)==k & postListG(:,4) == 1, 1:2));
                                NNdistRIn = [NNdistRIn; dR];
                            
                                [~, dR] = knnsearch(postListR(postListR(:,3)==k & postListR(:,4) == 0, 1:2), ...
                                    postListG(postListG(:,3)==k & postListG(:,4) == 0, 1:2));
                                NNdistROut = [NNdistROut; dR];
                                
                                %%%% Same-channel
                                
                                [~, dG] = knnsearch(postListG(postListG(:,3)==k & postListG(:,4) == 1, 1:2), ...
                                    postListG(postListG(:,3)==k & postListG(:,4) == 1, 1:2), 'K', 2);
                                NNdistGGIn = [NNdistGGIn; dG(dG > 0)];
                            
                                [~, dG] = knnsearch(postListG(postListG(:,3)==k & postListG(:,4) == 0, 1:2), ...
                                    postListG(postListG(:,3)==k & postListG(:,4) == 0, 1:2), 'K', 2);
                                NNdistGGOut = [NNdistGGOut; dG(dG > 0)];
                                
                                [~, dR] = knnsearch(postListR(postListR(:,3)==k & postListR(:,4) == 1, 1:2), ...
                                    postListR(postListR(:,3)==k & postListR(:,4) == 1, 1:2), 'K', 2);
                                NNdistRRIn = [NNdistRRIn; dR(dR > 0)];
                            
                                [~, dR] = knnsearch(postListR(postListR(:,3)==k & postListR(:,4) == 0, 1:2), ...
                                    postListR(postListR(:,3)==k & postListR(:,4) == 0, 1:2), 'K', 2);
                                NNdistRROut = [NNdistRROut; dR(dR > 0)];
                                
                            end
                            
                        end
                                                
                        
                        if isempty(postListG)
                            postListG = zeros(1, 4);
                        end
                        if isempty(postListR)
                            postListR = zeros(1, 4);
                        end
                        
                        InOutParticles{fN}(k,:) = [k numel(postListG((postListG(:,3)==k & postListG(:,4) == 1))), ...
                            numel(postListG((postListG(:,3)==k & postListG(:,4) == 0))), ...
                            numel(postListR((postListR(:,3)==k & postListR(:,4) == 1))), ...
                            numel(postListR((postListR(:,3)==k & postListR(:,4) == 0)))];

                    end
                   
                    %%%%%%%%%%
                    % Make histograms from data
                    
                   % trackResG = track(postListG, 10);
                    % trackResR = track(postListR, 10);
                    NNdistG = NNdistG * AnalParam.PixelSize * 1000;
                    NNdistR = NNdistR * AnalParam.PixelSize * 1000;

                    [a1, ~] = histc(NNdistG, histcList);
                    [a2, ~] = histc(NNdistR, histcList);

                    % Calc theoretical distribution for cell of size and
                    % particle density as the cells in this run.  

                    if ~isempty(a1)
                        a1(end) = [];
                    else
                        a1 = nan(numel(histcList)-1, 1);
                    end

                    if ~isempty(a2)
                        a2(end) = [];
                    else
                        a2 = nan(numel(histcList)-1, 1);
                    end

                    histMatrix(:,(2*fN)) = a1(:)/sum(a1(:));
                    histMatrix(:,(2*fN)+1) = a2(:)/sum(a2(:));
                    
                    %%%%%%%%%%%%%%%%
                    % Same channel
                    
                    % trackResG = track(postListG, 10);
                    % trackResR = track(postListR, 10);
                    NNdistGG = NNdistGG * AnalParam.PixelSize * 1000;
                    NNdistRR = NNdistRR * AnalParam.PixelSize * 1000;

                    [a1, ~] = histc(NNdistGG, histcList);
                    [a2, ~] = histc(NNdistRR, histcList);


                    if ~isempty(a1)
                        a1(end) = [];
                    else
                        a1 = nan(numel(histcList)-1, 1);
                    end

                    if ~isempty(a2)
                        a2(end) = [];
                    else
                        a2 = nan(numel(histcList)-1, 1);
                    end

                    histMatrixSameChannel(:,(2*fN)) = a1(:)/sum(a1(:));
                    histMatrixSameChannel(:,(2*fN)+1) = a2(:)/sum(a2(:));
                    
                    if handles.handles.SplitCenter.Value()
                        
                        NNdistGOut = NNdistGOut * AnalParam.PixelSize * 1000;
                        NNdistGIn = NNdistGIn * AnalParam.PixelSize * 1000;
                        NNdistRIn = NNdistRIn * AnalParam.PixelSize * 1000;
                        NNdistROut = NNdistROut * AnalParam.PixelSize * 1000;
                        
                        [a1p, ~] = histc(NNdistGOut, histcList);
                        [a2p, ~] = histc(NNdistGIn, histcList);
                        [a3p, ~] = histc(NNdistRIn, histcList);
                        [a4p, ~] = histc(NNdistROut, histcList);

                        if ~isempty(a1p)
                            a1p(end) = [];
                        else
                            a1p = nan(numel(histcList)-1, 1);
                        end

                        if ~isempty(a2p)
                            a2p(end) = [];
                        else
                            a2p = nan(numel(histcList)-1, 1);
                        end
                        
                        if ~isempty(a3p)
                            a3p(end) = [];
                        else
                            a3p = nan(numel(histcList)-1, 1);
                        end
                        
                        if ~isempty(a4p)
                            a4p(end) = [];
                        else
                            a4p = nan(numel(histcList)-1, 1);
                        end
                        
                        histMatrixSplit(:,(2*fN)) = a1p(:)/sum(a1p(:)); % Ch1 out
                        histMatrixSplit(:,(2*fN)+1) = a2p(:)/sum(a2p(:)); % Ch1 in
                        histMatrixSplit(:,(2*fN)+2) = a4p(:)/sum(a4p(:)); % Ch2 out
                        histMatrixSplit(:,(2*fN)+3) = a3p(:)/sum(a3p(:)); % Ch2 in
                        
                        %%%% Same channel
                        
                        NNdistGGOut = NNdistGGOut * AnalParam.PixelSize * 1000;
                        NNdistGGIn = NNdistGGIn * AnalParam.PixelSize * 1000;
                        NNdistRRIn = NNdistRRIn * AnalParam.PixelSize * 1000;
                        NNdistRROut = NNdistRROut * AnalParam.PixelSize * 1000;
                        
                        [a5p, ~] = histc(NNdistGGOut, histcList);
                        [a6p, ~] = histc(NNdistGGIn, histcList);
                        [a7p, ~] = histc(NNdistRRIn, histcList);
                        [a8p, ~] = histc(NNdistRROut, histcList);
                        
                        if ~isempty(a5p)
                            a5p(end) = [];
                        else
                            a5p = nan(numel(histcList)-1, 1);
                        end
                        
                        if ~isempty(a6p)
                            a6p(end) = [];
                        else
                            a6p = nan(numel(histcList)-1, 1);
                        end
                        
                        if ~isempty(a7p)
                            a7p(end) = [];
                        else
                            a7p = nan(numel(histcList)-1, 1);
                        end
                        
                        if ~isempty(a8p)
                            a8p(end) = [];
                        else
                            a8p = nan(numel(histcList)-1, 1);
                        end
                        
                        histMatrixSplitSameChannel(:,(2*fN)) = a5p(:)/sum(a5p(:)); % Ch1 out
                        histMatrixSplitSameChannel(:,(2*fN)+1) = a6p(:)/sum(a6p(:)); % Ch1 in
                        histMatrixSplitSameChannel(:,(2*fN)+2) = a8p(:)/sum(a8p(:)); % Ch2 out
                        histMatrixSplitSameChannel(:,(2*fN)+3) = a7p(:)/sum(a7p(:)); % Ch2 in

                    end
                    
                    
                    if ExportSeries || MakeGif
                        close(gifWindow);
                    end
            
                    if IncludeRandomPoints
                        % Shuffle which peaks go in each frame in
                        % postListG and postListR.  This represents
                        % spatially-consistient but
                        % temporally-scrambled data to give measure of
                        % nearest-neighbor distances for totally
                        % non-co-localized vesicles.
                        
                        bootList_GR = [];
                        bootList_RG = [];
                        
                        bootList_GG = [];
                        bootList_RR = [];
                        
                        shuffleLines.G = randperm(size(postListG, 1));
                        shuffleLines.R = randperm(size(postListR, 1));
                        
                        shuffG = [postListG(shuffleLines.G, 1:2) postListG(:,3:4)];
                        shuffR = [postListR(shuffleLines.R, 1:2) postListR(:,3:4)];
                        
                        for k = 1:(handles.N_frames-1)
                            
                            [~, dG] = knnsearch(shuffG(shuffG(:,3)==k, 1:2), shuffR(shuffR(:,3)==k, 1:2));
                            [~, dR] = knnsearch(shuffR(shuffR(:,3)==k, 1:2), shuffG(shuffG(:,3)==k, 1:2));
                            
                            
                            [~, dGG] = knnsearch(shuffG(shuffG(:,3)==k, 1:2), shuffG(shuffG(:,3)==k, 1:2), 'K', 2);
                            [~, dRR] = knnsearch(shuffR(shuffR(:,3)==k, 1:2), shuffR(shuffR(:,3)==k, 1:2), 'K', 2);
                            
                            if ~isempty(dG) && ~isempty(dR)
                                bootList_GR = [bootList_GR; dG];
                                bootList_RG = [bootList_RG; dR];
                                
                                bootList_GG = [bootList_GG; dGG(dGG > 0)];
                                bootList_RR = [bootList_RR; dRR(dRR > 0)];
 
                            end
                            
                        end
                        
                        % Make histograms from random data
                        bootList_GR = bootList_GR * AnalParam.PixelSize * 1000;
                        bootList_RG = bootList_RG * AnalParam.PixelSize * 1000;
                        
                        [aB1, ~] = histc(bootList_GR, histcList);
                        [aB2, ~] = histc(bootList_RG, histcList);
                        
                        if ~isempty(aB1)
                            aB1(end) = [];
                            
                        else
                            aB1 = nan(numel(histcList)-1, 1);
                        end
                        
                        if ~isempty(aB2)
                            aB2(end) = [];
                        else
                            aB2 = nan(numel(histcList)-1, 1);
                        end
                        
                        RandomHistMatrix(:,(2*fN)) = aB1(:)/sum(aB1(:));
                        RandomHistMatrix(:,(2*fN)+1) = aB2(:)/sum(aB2(:));
                        
                        %%%%%%%%
                        % Same channel
                        % Make histograms from random data
                        bootList_GG = bootList_GG * AnalParam.PixelSize * 1000;
                        bootList_RR = bootList_RR * AnalParam.PixelSize * 1000;
                        
                        [aB1sc, ~] = histc(bootList_GG, histcList);
                        [aB2sc, ~] = histc(bootList_RR, histcList);
                        
                        if ~isempty(aB1sc)
                            aB1sc(end) = [];
                            
                        else
                            aB1sc = nan(numel(histcList)-1, 1);
                        end
                        
                        if ~isempty(aB2sc)
                            aB2sc(end) = [];
                        else
                            aB2sc = nan(numel(histcList)-1, 1);
                        end
                        
                        RandomHistMatrixSameChannel(:,(2*fN)) = aB1sc(:)/sum(aB1sc(:));
                        RandomHistMatrixSameChannel(:,(2*fN)+1) = aB2sc(:)/sum(aB2sc(:));
                        
                        
                        if handles.handles.SplitCenter.Value()
                            
                            % shuffle in and out separately
                            shuffleLinesIn.G = randperm(sum(postListG(:,4) == 1, 1));
                            shuffleLinesOut.G = randperm(sum(postListG(:,4) == 0, 1));
                            
                            shuffleLinesIn.R = randperm(sum(postListR(:,4) == 1, 1));
                            shuffleLinesOut.R = randperm(sum(postListR(:,4) == 0, 1));
                        
                            inListG = postListG(postListG(:,4) == 1, :);
                            outListG = postListG(postListG(:,4) == 0, :);
                            
                            inListR = postListR(postListR(:,4) == 1, :);
                            outListR = postListR(postListR(:,4) == 0, :);
                            
                            shuffGIn = [inListG(shuffleLinesIn.G, 1:2) inListG(:,3:4)];
                            shuffGout = [outListG(shuffleLinesOut.G, 1:2) outListG(:,3:4)];
                            
                            shuffRIn = [inListR(shuffleLinesIn.R, 1:2) inListR(:,3:4)];
                            shuffRout = [outListR(shuffleLinesOut.R, 1:2) outListR(:,3:4)];

                            
                            for k = 1:(handles.N_frames-1)
                                    % Calc NNdistG and NNdistR for inner and
                                    % outer regions
                                    [~, dGIn] = knnsearch(shuffGIn(shuffGIn(:,3)==k, 1:2), ...
                                        shuffRIn(shuffRIn(:,3)==k, 1:2));
                                    bootList_GRIn = [bootList_GRIn; dGIn];

                                    [~, dGout] = knnsearch(shuffGout(shuffGout(:,3)==k, 1:2), ...
                                        shuffRout(shuffRout(:,3)==k, 1:2));
                                    bootList_GROut = [bootList_GROut; dGout];

                                    [~, dRin] = knnsearch(shuffRIn(shuffRIn(:,3)==k, 1:2), ...
                                        shuffGIn(shuffGIn(:,3)==k, 1:2));
                                    bootList_RGIn = [bootList_RGIn; dRin];

                                    [~, dRout] = knnsearch(shuffRout(shuffRout(:,3)==k, 1:2), ...
                                        shuffGout(shuffGout(:,3)==k, 1:2));
                                    bootList_RGOut = [bootList_RGOut; dRout];
                                    
                                    %%%%%%%%%%%%
                                    % Same channel
                                    
                                    [~, dGIn] = knnsearch(shuffGIn(shuffGIn(:,3)==k, 1:2), ...
                                        shuffGIn(shuffGIn(:,3)==k, 1:2), 'K', 2);
                                    bootList_GGIn = [bootList_GGIn; dGIn(dGIn > 0)];

                                    [~, dGout] = knnsearch(shuffGout(shuffGout(:,3)==k, 1:2), ...
                                        shuffGout(shuffGout(:,3)==k, 1:2), 'K', 2);
                                    bootList_GGOut = [bootList_GGOut; dGout(dGout > 0)];

                                    [~, dRin] = knnsearch(shuffRIn(shuffRIn(:,3)==k, 1:2), ...
                                        shuffRIn(shuffRIn(:,3)==k, 1:2), 'K', 2);
                                    bootList_RRIn = [bootList_RRIn; dRin(dRin > 0)];

                                    [~, dRout] = knnsearch(shuffRout(shuffRout(:,3)==k, 1:2), ...
                                        shuffRout(shuffRout(:,3)==k, 1:2), 'K', 2);
                                    bootList_RROut = [bootList_RROut; dRout(dRout > 0)];

                            end
                           
                            % Make histograms from random split data
                            bootList_GRIn = bootList_GRIn * AnalParam.PixelSize * 1000;
                            bootList_GROut = bootList_GROut * AnalParam.PixelSize * 1000;
                            bootList_RGIn = bootList_RGIn * AnalParam.PixelSize * 1000;
                            bootList_RGOut = bootList_RGOut * AnalParam.PixelSize * 1000;
                            
                            [aB1p, ~] = histc(bootList_GRIn, histcList);
                            [aB2p, ~] = histc(bootList_GROut, histcList);
                            [aB3p, ~] = histc(bootList_RGIn, histcList);
                            [aB4p, ~] = histc(bootList_RGOut, histcList);
                            
                            if ~isempty(aB1p)
                                aB1p(end) = [];
                                
                            else
                                aB1p = nan(numel(histcList)-1, 1);
                            end
                            
                            if ~isempty(aB2p)
                                aB2p(end) = [];
                            else
                                aB2p = nan(numel(histcList)-1, 1);
                            end
                            
                            if ~isempty(aB3p)
                                aB3p(end) = [];
                            else
                                aB3p = nan(numel(histcList)-1, 1);
                            end
                            
                            if ~isempty(aB4p)
                                aB4p(end) = [];
                            else
                                aB4p = nan(numel(histcList)-1, 1);
                            end
                            
                            RandomHistMatrixSplit(:,(2*fN)) = aB2p(:)/sum(aB2p(:)); % Ch1  out 
                            RandomHistMatrixSplit(:,(2*fN)+1) = aB1p(:)/sum(aB1p(:)); % Ch1 in
                            RandomHistMatrixSplit(:,(2*fN)+2) = aB4p(:)/sum(aB4p(:)); % Ch2 out
                            RandomHistMatrixSplit(:,(2*fN)+3) = aB3p(:)/sum(aB3p(:)); % Ch2 in
                            
                            
                            %%%%%%%%%%%%%%%%%%%%%
                            % Same channel
                            % Make histograms from random split data
                            bootList_GGIn = bootList_GGIn * AnalParam.PixelSize * 1000;
                            bootList_GGOut = bootList_GGOut * AnalParam.PixelSize * 1000;
                            bootList_RRIn = bootList_RRIn * AnalParam.PixelSize * 1000;
                            bootList_RROut = bootList_RROut * AnalParam.PixelSize * 1000;
                            
                            [aB5p, ~] = histc(bootList_GGIn, histcList);
                            [aB6p, ~] = histc(bootList_GGOut, histcList);
                            [aB7p, ~] = histc(bootList_RRIn, histcList);
                            [aB8p, ~] = histc(bootList_RROut, histcList);
                            
                            if ~isempty(aB5p)
                                aB5p(end) = [];
                                
                            else
                                aB5p = nan(numel(histcList)-1, 1);
                            end
                            
                            if ~isempty(aB6p)
                                aB6p(end) = [];
                            else
                                aB6p = nan(numel(histcList)-1, 1);
                            end
                            
                            if ~isempty(aB7p)
                                aB7p(end) = [];
                            else
                                aB7p = nan(numel(histcList)-1, 1);
                            end
                            
                            if ~isempty(aB8p)
                                aB8p(end) = [];
                            else
                                aB8p = nan(numel(histcList)-1, 1);
                            end
                            
                            RandomHistMatrixSplitSameChannel(:,(2*fN)) = aB6p(:)/sum(aB6p(:)); % Ch1  out 
                            RandomHistMatrixSplitSameChannel(:,(2*fN)+1) = aB5p(:)/sum(aB5p(:)); % Ch1 in
                            RandomHistMatrixSplitSameChannel(:,(2*fN)+2) = aB8p(:)/sum(aB8p(:)); % Ch2 out
                            RandomHistMatrixSplitSameChannel(:,(2*fN)+3) = aB7p(:)/sum(aB7p(:)); % Ch2 in
                            
                        end
                        

                        
                    end
                    
            

                
%                 assignin('base', 'histMatrix', histMatrix);

                if get(handles.handles.ExportHistData, 'Value') == 1
                    
                    plot(histAx, histcList(1:(end-1)), histMatrix(:,2+(2*(fN-1))), 'LineStyle', '-', 'Color', handles.ColorList(fN,:), 'LineWidth', 2);
                    if fN == 1
                        set(histAx, 'NextPlot', 'add')
                    end
                    plot(histAx, histcList(1:(end-1)), histMatrix(:,3+(2*(fN-1))), 'LineStyle', '--', 'Color', handles.ColorList(fN,:), 'LineWidth', 2);

                    xlabel(histAx, 'Cross-channel Nearest-neighbor Distance (nm)', 'FontSize', 12);
                    ylabel(histAx, 'PDF', 'FontSize', 12)
                    set(histogramFigure, 'Position', [100 100 800 600])
                    set(histAx, 'LooseInset', get(histAx, 'TightInset'));
                    
                    if IncludeRandomPoints && ~(isempty(aB1) && isempty(aB2))
                        plot(histAx, histcList(1:(end-1)), RandomHistMatrix(:,2+(2*(fN-1))), 'LineStyle', ':', 'Color', handles.ColorList(fN,:), 'LineWidth', 2);
                        plot(histAx, histcList(1:(end-1)), RandomHistMatrix(:,3+(2*(fN-1))), 'LineStyle', '-.', 'Color', handles.ColorList(fN,:), 'LineWidth', 2);
                        
                        legendString{4*(fN-1)+1} = strcat(fileName, ' 2 -> 1');
                        legendString{4*(fN-1)+2} = strcat(fileName, ' 1 -> 2');
                        legendString{4*(fN-1)+3} = strcat(fileName, ' RAND 2 -> 1');
                        legendString{4*(fN-1)+4} = strcat(fileName, ' RAND 1 -> 2');
                        
                    else
                        legendString{2*(fN-1)+1} = strcat(fileName, ' 2 -> 1');
                        legendString{2*(fN-1)+2} = strcat(fileName, ' 1 -> 2');
                    end
                    
                    

                    if fN == length(handles.SelectedFiles)
                        set(histAx, 'NextPlot', 'replace')
                    end
                        
                        
                    if AnalParam.CenterChannel ~= 3
                        plot(InOutAxes, InOutParticles{fN}(:,1), InOutParticles{fN}(:,2), 'LineStyle', '-', 'Color', handles.ColorList(fN,:), 'LineWidth', 2);
                        if fN == 1
                            set(InOutAxes, 'NextPlot', 'add')
                        end
                        plot(InOutAxes, InOutParticles{fN}(:,1), InOutParticles{fN}(:,3), 'LineStyle', '--', 'Color', handles.ColorList(fN,:), 'LineWidth', 2);
                        plot(InOutAxes, InOutParticles{fN}(:,1), InOutParticles{fN}(:,4), 'LineStyle', '-', 'Color', handles.ColorList(fN+size(handles.ColorList, 1)/2,:), 'LineWidth', 2);
                        plot(InOutAxes, InOutParticles{fN}(:,1), InOutParticles{fN}(:,5), 'LineStyle', '--', 'Color', handles.ColorList(fN+size(handles.ColorList, 1)/2,:), 'LineWidth', 2);


                        
                        xlabel(InOutAxes, 'Time (frame)', 'FontSize', 12);
                        ylabel(InOutAxes, 'N Particles', 'FontSize', 12)
                        set(InOutFigure, 'Position', [100 100 800 600])
                        set(InOutAxes, 'LooseInset', get(InOutAxes, 'TightInset'));

                        if fN == length(handles.SelectedFiles)
                            set(InOutAxes, 'NextPlot', 'replace')
                        end
                    
         
                        legString{4*(fN-1)+1} = strcat(fileName, ' Ch 1 Out');
                        legString{4*(fN-1)+2} = strcat(fileName, ' Ch 1 In');
                        legString{4*(fN-1)+3} = strcat(fileName, ' Ch 2 Out');
                        legString{4*(fN-1)+4} = strcat(fileName, ' Ch 2 In');
                        
                        InOutCheck(fN) = 1;
                        
                    else
                        
                        plot(InOutAxes, InOutParticles{fN}(:,1), InOutParticles{fN}(:,2), 'LineStyle', '-', 'Color', handles.ColorList(fN,:), 'LineWidth', 2);
                        if fN == 1
                            set(InOutAxes, 'NextPlot', 'add')
                        end
%                         plot(InOutAxes, InOutParticles{fN}(:,1), InOutParticles{fN}(:,3), 'LineStyle', '--', 'Color', handles.ColorList(fN,:), 'LineWidth', 2);
                        plot(InOutAxes, InOutParticles{fN}(:,1), InOutParticles{fN}(:,4), 'LineStyle', '-', 'Color', handles.ColorList(fN+size(handles.ColorList, 1)/2,:), 'LineWidth', 2);
%                         plot(InOutAxes, InOutParticles{fN}(:,1), InOutParticles{fN}(:,5), 'LineStyle', '--', 'Color', handles.ColorList(fN+10,:), 'LineWidth', 2);


                        
                        xlabel(InOutAxes, 'Time (frame)', 'FontSize', 12);
                        ylabel(InOutAxes, 'N Particles', 'FontSize', 12)
                        set(InOutFigure, 'Position', [100 100 800 600])
                        set(InOutAxes, 'LooseInset', get(InOutAxes, 'TightInset'));

                        if fN == length(handles.SelectedFiles)
                            set(InOutAxes, 'NextPlot', 'replace')
                        end
                    
         
                        legString{2*(fN-1)+1} = strcat(fileName, ' Ch 1');
                        legString{2*(fN-1)+2} = strcat(fileName, ' Ch 2');
                        
                        InOutCheck(fN) = 1;
                        
                        
                    end
                    
                end

            
            end % fN
            if get(handles.handles.ExportHistData, 'Value') == 1
                
                legend(histAx, legendString, 'interpreter', 'none');
                histImgName = strcat(folderPath, '\', fileName, '.png');
                hINum = 1;
                while exist(histImgName, 'file')
                    
                    histImgName((end-3:end)) = [];
                    histImgName(isstrprop(histImgName,'digit')) = [];
                    histImgName = sprintf('%s%02d.png', histImgName, hINum);
                    hINum = hINum + 1;
                    
                end
                    
                
                print(histogramFigure, '-dpng', strcat(histImgName(1:(end-4)), '_XChanNNDist.png'));
                
                [~, hImg] = fileparts(histImgName);

                
                %%%%%%%%%%%%%%%
                % Print histogram data file
                
                HistFileName = fullfile(folderPath, strcat(hImg, '_XChanNNDist.txt'));
                WriteHistogramsToFile(histMatrix, HistFileName, fileNameArray, 2);
                
                HistFileName = fullfile(folderPath, strcat(hImg, '_SameChanNNDist.txt'));
                WriteHistogramsToFile(histMatrixSameChannel, HistFileName, fileNameArray, 2);
                
                if handles.handles.SplitCenter.Value()
                
                    %%%%%%%%%%%%%%%
                    % Print SPLIT DATA histogram to file

                    HistFileName = fullfile(folderPath, strcat(hImg, '_XChanNNDistSplit.txt'));
                    WriteHistogramsToFile(histMatrixSplit, HistFileName, fileNameArray, 4);
                    
                    HistFileName = fullfile(folderPath, strcat(hImg, '_SameChanNNDistSplit.txt'));
                    WriteHistogramsToFile(histMatrixSplitSameChannel, HistFileName, fileNameArray, 4);
                    
                    
                    
                end
                
                if IncludeRandomPoints
                        %%%%%%%%%%%%%%%%%
                        % Include random data
                        %%%%%%%%%%%%%%%
                        % Print histogram data file

                        HistFileName = fullfile(folderPath, strcat(hImg, '_XChanNNDistRandomized.txt'));
                        WriteHistogramsToFile(RandomHistMatrix, HistFileName, fileNameArray, 2);
                        
                        HistFileName = fullfile(folderPath, strcat(hImg, '_SameChanNNDistRandomized.txt'));
                        WriteHistogramsToFile(RandomHistMatrixSameChannel, HistFileName, fileNameArray, 2);
                        
                        
                        if handles.handles.SplitCenter.Value()
                            % Print random split data to file
                            HistFileName = fullfile(folderPath, strcat(hImg, '_XChanNNDistRandomizedSplit.txt'));
                            WriteHistogramsToFile(RandomHistMatrixSplit, HistFileName, fileNameArray, 2);
                            
                            HistFileName = fullfile(folderPath, strcat(hImg, '_SameChanNNDistRandomizedSplit.txt'));
                            WriteHistogramsToFile(RandomHistMatrixSplitSameChannel, HistFileName, fileNameArray, 2);
                            
                        end
                        
                end
                

                    %%%%%%%%%%%%%%%%%%%%
                    % Center In/Out data
                    legend(InOutAxes, legString, 'interpreter', 'none');

                    %%%%%%%%%%%%%%%
                    % Print histogram data file
                    % Count of points in and out of center region

                    InOutFileName = fullfile(folderPath, strcat(hImg, '_CountInOut.txt'));

                    fID = fopen(InOutFileName, 'w+');

                    
                    fNum = 0;
                    for fNms = 1:length(handles.SelectedFiles);
                        
                    	fprintf(fID, '#####################\r\n');
                        fprintf(fID, '# Files analyzed : \r\n');

                        headerString = 'Time (frame)';
                        
                        if InOutCheck(fNms) == 1
                            fNum = fNum + 1;
                            fprintf(fID, '# %.0f.  %s \r\n', fNum, fileNameArray{fNms});
                            if AnalParam.CenterChannel ~= 3
                                headerString = sprintf('%s\t%.0f--Ch1 Out\t%.0f--Ch1 In\t%.0f--Ch2 Out\t%.0f--Ch2 In', headerString, fNum, fNum, fNum, fNum);
                            else
                                headerString = sprintf('%s\t%.0f--Ch1\t%.0f--Ch2', headerString, fNum, fNum);
                            end
                        end
                    
                        fprintf(fID, '#####################\r\n');
                        fprintf(fID, '%s\r\n', headerString);
                        
                        
                        for ln = 1:size(InOutParticles{fNms}, 1)
                            pLn = InOutParticles{fNms}(ln,:);
                            pLn(isnan(pLn)) = 0;
                            if AnalParam.CenterChannel ~= 3
                                fprintf(fID, '%.0f\t%.0f\t%.0f\t%.0f\t%.0f\r\n', pLn(1),pLn(2), pLn(3), pLn(4), pLn(5));
                            else
                                fprintf(fID, '%.0f\t%.0f\t%.0f\r\n', pLn(1),pLn(2),pLn(4));
                            end
                        end
                        
                        
                    end
                    fclose(fID);
                    

                    print(InOutFigure, '-dpng', strcat(hImg, '_CountInOut', '.png'));

              

            end
            
            set(handles.handles.fig3, 'Pointer', 'arrow');
            set(findobj('Parent', handles.handles.fig3, 'type', 'uicontrol'), 'enable', 'on');
            drawnow;
        end
        
        function WriteHistogramsToFile(histMatrixwrite, fileNameWrite, fNarray, NColsPerSet)
            
            % Handler function for writing histogram data to TXT file
            
            fID = fopen(fileNameWrite, 'w+');
            fprintf(fID, '#####################\r\n');
            fprintf(fID, '# Files analyzed : \r\n');
            
            headerString = 'Distance (nm)';
            
            for fNms = 1:length(fNarray);
                fprintf(fID, '# %.0f.  %s \r\n', fNms, fNarray{fNms});
                
                if NColsPerSet == 2
                    headerString = sprintf('%s\t%.0f--Ch1\t%.0f--Ch2', headerString, fNms, fNms);
                elseif NColsPerSet == 4
                    headerString = sprintf('%s\t%.0f--Ch1Out\t%.0f--Ch1In\t%.0f--Ch2Out\t%.0f--Ch2In', headerString, fNms, fNms, fNms, fNms);
                end
            end
            fprintf(fID, '#####################\r\n');
            fprintf(fID, '%s\r\n', headerString);
            
            fclose(fID);
            dlmwrite(fileNameWrite, histMatrixwrite, '-append', 'delimiter', '\t', 'newline', 'pc');
            
        end

                   
        
        
    end


%%%%%%%%%%%%%%%%%%%%%%
% Use uigetfile to load up a file

    function Load_pts(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        [fname, pathname, filterindex] = uigetfile({'*.lsm', 'LSM file (*.lsm)';'*.czi', 'CZI file (*.czi)'});
        
        if filterindex == 1;
            
            if ~strcmp(fullfile(pathname, fname), handles.Load_file)
                % Reset stuff now that there is a new file being loaded (as long as
                % it's actually new).
                
                
                
            end
            
            if ~isequal(fname, 0) && ~isequal(pathname, 0)
                
                DoTheLoadThing(pathname, fname);
                
            end
            
        end
        
    end
    
%%%%%%%%%%%%%%%%%%%%%%
% Edit text box to load file

    function Load_edit(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        text_input = get(handles.handles.Load_text, 'String');
        %disp(text_input)
        
        if exist(text_input, 'file') == 2;
            
            [pN, fN, extN] = fileparts(text_input);
            
            DoTheLoadThing(pN, strcat(fN, extN));
            
        end
            

    end
    
%%%%%%%%%%%%%%%%%%%%%%
% General load function
    
    function DoTheLoadThing(pathname, fname)
            
        set(findobj('Parent', handles.handles.slider_panel, 'Type', 'uicontrol'), 'Enable', 'on');
        set(handles.handles.fndCtrChannel, 'SelectedObject', handles.handles.fndCtrChanButton(handles.CenterChannel));
        
        if handles.CenterChannel == 3
        
            set(handles.handles.fndCtr_slide_hand, 'Enable', 'off')
            set(handles.handles.fndCtr_slide_box, 'Enable', 'off')
            set(handles.handles.fndCtr_Erode_box, 'Enable', 'off')
        
        end
        
        set(handles.handles.Load_text, 'String', fullfile(pathname, fname));
        handles.Load_file = fullfile(pathname, fname);
        
        load_wait = waitbar(0, 'Loading File');
       
        
        metaData = imreadBFmeta(handles.Load_file);
        
        handles.Img_stack = zeros(metaData.width, metaData.height, metaData.channels, metaData.nframes);
        waitbar(0.1, load_wait);
        handles.Img_stack(:,:,1,:) = imreadBF(handles.Load_file, 1:metaData.zsize, 1:metaData.nframes, 1);
        waitbar(0.4, load_wait);
        handles.Img_stack(:,:,2,:) = imreadBF(handles.Load_file, 1:metaData.zsize, 1:metaData.nframes, 2);
        waitbar(0.7, load_wait);
        handles.Img_stack(handles.Img_stack < 0) = handles.Img_stack(handles.Img_stack < 0) + 255;
        waitbar(0.75, load_wait);
        
                
        
        handles.N_frames = metaData.nframes;
        
        % Pull slider value
        slide_frame = 1 + round((handles.N_frames - 1)*(get(handles.handles.slide_hand, 'Value')));
        
        if handles.N_frames == 1;
            set(handles.handles.slide_hand, 'SliderStep', [1 1]);
            
        else
            
            set(handles.handles.slide_hand, 'SliderStep', [1/(handles.N_frames-1) 1/(handles.N_frames-1)]);
            
        end
        
        slide_frame = min([handles.N_frames slide_frame]);
        set(handles.handles.slide_box, 'String', num2str(slide_frame));
        
        OldXLimits = [0.5 size(handles.Img_stack, 2)+0.5];
        OldYLimits = [0.5 size(handles.Img_stack, 1)+0.5];
        set(handles.handles.ax1, 'XLim', OldXLimits, 'YLim', OldYLimits);
        set(handles.handles.ax2, 'XLim', OldXLimits, 'YLim', OldYLimits);
        
        temp_left = reshape(handles.Img_stack(:,:,1,:), [], handles.N_frames);
        handles.Min_max_left = [min(temp_left)' max(temp_left)'];
        handles.Display_range_left = [min(temp_left(:)) max(temp_left(:))];
        
        if handles.N_channels == 2;
            temp_right = reshape(handles.Img_stack(:,:,2,:), [], handles.N_frames);
            handles.Min_max_right = [min(temp_right)' max(temp_right)'];
            handles.Display_range_right = [min(temp_right(:)) max(temp_right(:))];
        end
        
        clear temp_left temp_right
        
        % Set Intensity threshold levels
        minMax1 = [min(handles.Min_max_left(:,1)) max(handles.Min_max_left(:,2))];
        set(handles.handles.Ptcl_slide_hand_left, 'Min', min(minMax1), 'Max', max(minMax1),...
            'SliderStep', [.05/(diff(minMax1)) 1/diff(minMax1)]);
        
        minMax2 = [min(handles.Min_max_right(:,1)) max(handles.Min_max_right(:,2))];
        set(handles.handles.Ptcl_slide_hand_right, 'Min', min(minMax2), 'Max', max(minMax2),...
            'SliderStep', [.05/(diff(minMax2)) 1/diff(minMax2)]);
        
        minMax = [min([minMax1 minMax2]) max([minMax1 minMax2])];
        set(handles.handles.bkgd_slide_hand, 'Min', min(minMax), 'Max', max(minMax),...
            'SliderStep', [1/(diff(minMax)) 10/diff(minMax)]);
        
        set(handles.handles.fndCtr_slide_hand, 'Min', min(minMax), 'Max', max(minMax),...
            'SliderStep', [1/(diff(minMax)) 10/diff(minMax)]);
        
        
        handles.PixelSize = metaData.raw.get('Series 0 VoxelSizeY');
        set(handles.handles.pixelSizeBox, 'String', sprintf('%.5f', handles.PixelSize))
        
        
        guidata(findobj('Tag', 'TIFF viewer'), handles);
        displayBkgdThresholdBndry;
        % Go ahead and get initial points detection done
        BandpassImageStack;
        calculateDetectedParticles('both');
        
        
        Display_images_in_axes;
        
        

        
        waitbar(1, load_wait);
        close(load_wait)
        
        
        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Display images in axes.  Used by multiple calls in GUI.

    function Display_images_in_axes(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
               
        if isempty(handles.Load_file) % No data loaded, just dummy images
            
            ax1 = handles.handles.ax1;
            ax2 = handles.handles.ax2;


            path_here = mfilename('fullpath');

            if isdeployed
                    logo_1 = BMIFLogoGenerate;
                    fill_image = imagesc(Vector2Colormap(-logo_1,handles.Left_color), 'Parent', ax1);
                    fill_image2 = imagesc(Vector2Colormap(-logo_1,handles.Right_color), 'Parent', ax2);
                    set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');
                    set(fill_image2, 'Tag', 'fill_image_right', 'HitTest', 'on');
            else
                logo_file = fullfile(fileparts(path_here), 'BMIF_logo.jpg');

                if exist(logo_file, 'file') == 2;

                    logo_hold = single(imread(logo_file));
                    logo_1 = logo_hold(:,:,1);
                    clear logo_hold  
                    fill_image = imagesc(Vector2Colormap(-logo_1,handles.Left_color), 'Parent', ax1);
                    fill_image2 = imagesc(Vector2Colormap(-logo_1,handles.Right_color), 'Parent', ax2);
                    set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');
                    set(fill_image2, 'Tag', 'fill_image_right', 'HitTest', 'on');

                else

                    % Dummy data to put into the axes on startup
                    z=peaks(1000);
                    z = z./max(abs(z(:)));
                    fill_image = imshow(z, 'Parent', ax1, 'ColorMap', jet, 'DisplayRange', [min(z(:)) max(z(:))]);
                    set(fill_image, 'Tag', 'fill_image_left', 'HitTest', 'on');
                    freezeColors(ax1);

                end
            end
                
        else        
                    
            if handles.N_channels == 1;

                % Pull slider value
                slide_frame = 1 + round((handles.N_frames - 1)*(get(slide_hand, 'Value')));


                    if handles.Autoscale_left == 0;
                        min_max_left = handles.Display_range_left;
                    else
                        min_max_left = handles.Min_max_left(slide_frame, :);
                    end
                    
                    OldXLimits = get(ax1, 'XLim');
                    OldYLimits = get(ax1, 'YLim');

                    % Set left axis to that frame
                 left_img = image(Vector2Colormap_setscale(handles.Img_stack(:,:,slide_frame,1), handles.Left_color, min_max_left), ...
                    'Parent', ax1, 'Tag', 'Left Image');
                    set(ax1, 'xtick', [], 'ytick', []);
                    axis(ax1, 'image');
                    set(ax1, 'XLim', OldXLimits, 'YLim', OldYLimits);
                    

            elseif handles.N_channels == 2;

                
                    % Pull slider value
                    handles.handles.slide_frame = 1 + round((handles.N_frames - 1)*(get(handles.handles.slide_hand, 'Value')));


                    % Set both axes to that frame


                    if handles.Autoscale_left == 0;
                        min_max_left = handles.Display_range_left;
                    else
                        min_max_left = handles.Min_max_right(handles.handles.slide_frame, :);
                    end

                    if handles.Autoscale_right == 0;
                        min_max_right = handles.Display_range_right;
                    else
                        min_max_right = handles.Min_max_right(handles.handles.slide_frame, :);
                    end
                    OldXLimits = get(handles.handles.ax1, 'XLim');
                    OldYLimits = get(handles.handles.ax1, 'YLim');

                    left_img = image(Vector2Colormap_setscale(handles.Img_stack(:,:,1, handles.handles.slide_frame), handles.Left_color, min_max_left), ...
                        'Parent', handles.handles.ax1, 'Tag', 'Left Image');
                        set(handles.handles.ax1, 'xtick', [], 'ytick', []);
                        axis(handles.handles.ax1, 'image');
                        set(handles.handles.ax1, 'XLim', OldXLimits, 'YLim', OldYLimits);

                    OldXLimits = get(handles.handles.ax2, 'XLim');
                    OldYLimits = get(handles.handles.ax2, 'YLim');
%                     disp(handles.Right_color)
                    right_img = image(Vector2Colormap_setscale(handles.Img_stack(:,:,2,handles.handles.slide_frame), handles.Right_color, min_max_right), ...
                        'Parent', handles.handles.ax2, 'Tag', 'Right Image');
                         set(handles.handles.ax2, 'xtick', [], 'ytick', []);
                         axis(handles.handles.ax2, 'image');
                         set(handles.handles.ax2, 'XLim', OldXLimits, 'YLim', OldYLimits);
                         

            end
            
            displayBkgdThresholdBndry;
            
            
            if handles.CenterChannel ~= 3
            
                displayCenterThreshold;
                
            end
            
        end
        
        if handles.Left_invert == 1;
            
            axis_handle = get(findobj('Tag', 'axes_panel1'), 'Children');
            set(axis_handle, 'XDir', 'reverse');
            
        end
        
        if handles.Right_invert == 1;
            
            axis_handle = get(findobj('Tag', 'axes_panel2'), 'Children');
            set(axis_handle, 'XDir', 'reverse');
            
        end

        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Bandpass image stack 
% Saves time for calls later

    function BandpassImageStack(varargin)

        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        handles.bPassStack = zeros(size(handles.Img_stack));
        
        bpassVals = str2double(get(handles.handles.Ptcl_Bpass_box, 'String'));
        
        for k = 1:size(handles.bPassStack, 3);
            for m = 1:size(handles.bPassStack, 4);
        
               handles.bPassStack(:,:,k, m) = bpass(handles.Img_stack(:,:,k,m), bpassVals(1), bpassVals(2));
               
            end
            
        end
        
        guidata(handles.handles.fig1, handles);
    end


%%%%%%%%%%%%%%%%%%%%%%
% Display Background threshold boundary

    function displayBkgdThresholdBndry(varargin)

        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        delete(findobj('Parent', handles.handles.ax1, 'Type', 'line', 'Color', 'w'));
        delete(findobj('Parent', handles.handles.ax2, 'Type', 'line', 'Color', 'w'));
        
        set(handles.handles.ax1, 'NextPlot', 'add')
        set(handles.handles.ax2, 'NextPlot', 'add')
        
        frameNum = str2double(get(handles.handles.slide_box, 'String'));
        bkgdVal = str2double(get(handles.handles.bkgd_slide_box, 'String'));
        erodePixels = str2double(get(handles.handles.bkgd_dilate_box, 'String'));
        
        % Find cell border
        gT = (handles.Img_stack(:,:,handles.BackgroundChannel, frameNum) > (bkgdVal));
        gT = imfill(gT, 'holes');
        gT = bwmorph(gT, 'open');
        regs = regionprops(gT, 'area', 'PixelIdxList');
        rA = vertcat(regs.Area);
        regs(rA ~= max(rA)) = [];
        bwImg = zeros(size(handles.Img_stack, 1), size(handles.Img_stack, 2), 1);
        if ~isempty(regs)
            bwImg(regs.PixelIdxList) = 1;
        end
        bwImg = reshape(bwImg, size(handles.Img_stack, 1), size(handles.Img_stack, 2));

        Bo = bwboundaries(bwImg, 'noholes');

        bwImg = bwmorph(bwImg, 'erode', erodePixels);

        B = bwboundaries(bwImg, 'noholes');
        
        for m = 1:length(B)
            plot(handles.handles.ax1, B{m}(:,2), B{m}(:,1), 'w')
            plot(handles.handles.ax2, B{m}(:,2), B{m}(:,1), 'w')
        end

        for m = 1:length(Bo)
            plot(handles.handles.ax1, Bo{1}(:,2), Bo{1}(:,1), 'w:')
            plot(handles.handles.ax2, Bo{1}(:,2), Bo{1}(:,1), 'w:')
        end
        
        set(handles.handles.ax1, 'NextPlot', 'replace')
        set(handles.handles.ax2, 'NextPlot', 'replace')
        
        handles.bwImg = bwImg;
        
        guidata(handles.handles.fig1, handles);
                   
    end

%%%%%%%%%%%%%%%%%%%%%%
% Display center threshold (if needed)

    function displayCenterThreshold(varargin)
        
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        if ismember(handles.CenterChannel, [1, 2])
            
            delete(findobj('Parent', handles.handles.ax1, 'Type', 'line', 'Color', 'm'));
            delete(findobj('Parent', handles.handles.ax2, 'Type', 'line', 'Color', 'm'));
            
            set(handles.handles.ax1, 'NextPlot', 'add')
            set(handles.handles.ax2, 'NextPlot', 'add')
            
            frameNum = str2double(get(handles.handles.slide_box, 'String'));
            ctrVal = handles.CenterIntensity;
            dilatePixels = handles.FindCtrDilateDiameter;
            
            %         disp(ctrVal)
            
            % Find cell border
            gT = (handles.Img_stack(:,:,handles.CenterChannel, frameNum) > (ctrVal));
            regs = regionprops(gT, 'area', 'PixelIdxList');
            rA = vertcat(regs.Area);
            regs(rA ~= max(rA)) = [];
            bwImg = false(size(handles.Img_stack, 1)*size(handles.Img_stack, 2), 1);
            bwImg(vertcat(regs.PixelIdxList)) = 1;
            bwImg = reshape(bwImg, size(handles.Img_stack, 1), size(handles.Img_stack, 2));
            
            Bo = bwboundaries(bwImg, 'noholes');
            
            bwImg = bwmorph(bwImg, 'dilate', dilatePixels);
            
            ctrMask = handles.bwImg;
            ctrMask(bwImg) = 0;
            B = bwboundaries(bwImg, 'noholes');
            
            for m = 1:length(B)
                plot(handles.handles.ax1, B{m}(:,2), B{m}(:,1), 'm')
                plot(handles.handles.ax2, B{m}(:,2), B{m}(:,1), 'm')
            end
            
            for m = 1:length(Bo)
                plot(handles.handles.ax1, Bo{1}(:,2), Bo{1}(:,1), 'm:')
                plot(handles.handles.ax2, Bo{1}(:,2), Bo{1}(:,1), 'm:')
            end
            
            set(handles.handles.ax1, 'NextPlot', 'replace')
            set(handles.handles.ax2, 'NextPlot', 'replace')
            
        elseif handles.CenterChannel == 4
            
            % Center channel is user-defined
            
            frameNum = str2double(get(handles.handles.slide_box, 'String'));
            
            % Skip if impoly is already present
            if isempty(findobj('parent', handles.handles.ax1, 'tag', 'impoly'))
            

                % Display user-defined object for that frame

                currPoly = impoly(handles.handles.ax1, handles.UserDefinedCenterROIs{frameNum});
                currPoly.setColor('m');
                currPoly.setClosed(true);
                currPoly.addNewPositionCallback(@roiPolyUpdate);
                fcn = makeConstrainToRectFcn('impoly', get(gca,'XLim'), get(gca,'YLim'));
                currPoly.setPositionConstraintFcn(fcn);
 
            else
                % skip
            end
            
                delete(findobj('parent', handles.handles.ax2, 'color', 'm'));
                set(handles.handles.ax2, 'nextplot', 'add');
                plot(handles.handles.ax2, handles.UserDefinedCenterROIs{frameNum}([1:end 1], 1), ...
                    handles.UserDefinedCenterROIs{frameNum}([1:end 1], 2), 'm');
            
        end
        
        guidata(handles.handles.fig1, handles);
        
        
        calculateDetectedParticles('both');
        
    end

%%%%%%%%%%%%%%%%%%%%%%
% Display detected points

    function calculateDetectedParticles(whichSide, varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
            pkfndThresholdG = handles.ParticleIntensityThresholds(1);
            pkfndRad = handles.peakfindRadius;
            cntrdRad = handles.centroidRadius;
            frameNow = str2double(get(handles.handles.slide_box, 'String'));
        
        
        if handles.CenterChannel ~= 3
            ctrVal = handles.CenterIntensity;
            dilatePixels = handles.FindCtrDilateDiameter;
            
            %         disp(ctrVal)
            
            % Find cell border
            if ismember(handles.CenterChannel, [1 2])
            
                gT = (handles.Img_stack(:,:,handles.CenterChannel, frameNow) > (ctrVal));
                regs = regionprops(gT, 'area', 'PixelIdxList');
                rA = vertcat(regs.Area);
                regs(rA ~= max(rA)) = [];
                bwImg = false(size(handles.Img_stack, 1)*size(handles.Img_stack, 2), 1);
                bwImg(vertcat(regs.PixelIdxList)) = 1;
                bwImg = reshape(bwImg, size(handles.Img_stack, 1), size(handles.Img_stack, 2));

                bwImg = bwmorph(bwImg, 'dilate', dilatePixels);

                ctrMask = handles.bwImg - bwImg;

            elseif handles.CenterChannel == 4
                
                ctrMask = ~poly2mask(handles.UserDefinedCenterROIs{frameNow}(:,1), ...
                    handles.UserDefinedCenterROIs{frameNow}(:,2), ...
                    size(handles.Img_stack, 1), size(handles.Img_stack, 2));
                
                
            end
            
           
        
        end
        
        if strcmp(whichSide, 'left') || strcmp(whichSide, 'both')
            
            
            
            delete(findobj('Parent', handles.handles.ax1, 'color', 'c', 'marker', 'x'));
            delete(findobj('Parent', handles.handles.ax1, 'color', 'c', 'marker', 's'));

            pkG = pkfnd(handles.bPassStack(:,:,1,frameNow), pkfndThresholdG, pkfndRad);
%             disp('pkfnd 1')

            inList = zeros(size(pkG, 1), 1);
            for m = 1:size(pkG, 1)
                inList(m) = handles.bwImg(pkG(m,2), pkG(m,1));
            end

            pkG(inList == 0, :) = [];
            
            postListG = [];

            if ~isempty(pkG)

                centG = cntrd(handles.bPassStack(:,:,1,frameNow), pkG, cntrdRad);

                postListG = [postListG; centG(:,1), centG(:,2)];

            end
            
            postListG = [postListG, ones(size(postListG, 1), 1)];
            
            if handles.CenterChannel ~= 3
                for m = 1:size(postListG, 1)
                    postListG(m,3) = ctrMask((pkG(m,2)), (pkG(m,1)));
                end  
            end


            handles.ParticleList{1} = postListG;
            handles.pkG = pkG;
            
            if ~isempty(postListG);
                set(handles.handles.ax1, 'NextPlot', 'add');

                xmark = plot(handles.handles.ax1, handles.ParticleList{1}(handles.ParticleList{1}(:,3) == 1,1), handles.ParticleList{1}(handles.ParticleList{1}(:,3) == 1,2), 'cx');
                dotmark = plot(handles.handles.ax1, handles.ParticleList{1}(handles.ParticleList{1}(:,3) == 0,1), handles.ParticleList{1}(handles.ParticleList{1}(:,3) == 0,2), 'cs', 'markerFaceColor', 'c', 'markerSize', 3);
                set(xmark, 'hittest', 'off');
                set(dotmark, 'hittest', 'off');
            
                set(handles.handles.ax1, 'NextPlot', 'replace');
            end
            
        end
        
        if strcmp(whichSide, 'right') || strcmp(whichSide, 'both')
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            
            delete(findobj('Parent', handles.handles.ax2, 'color', 'r', 'marker', 'x'));
            delete(findobj('Parent', handles.handles.ax2, 'color', 'r', 'marker', 's'));

            pkfndThresholdR = handles.ParticleIntensityThresholds(2);
            pkfndRad = handles.peakfindRadius;
            cntrdRad = handles.centroidRadius;
            frameNow = str2double(get(handles.handles.slide_box, 'String'));

            pkR = pkfnd(handles.bPassStack(:,:,2,frameNow), pkfndThresholdR, pkfndRad);

            inList = zeros(size(pkR, 1), 1);
            for m = 1:size(pkR, 1)
                inList(m) = handles.bwImg(pkR(m,2), pkR(m,1));
            end

            pkR(inList == 0, :) = [];

            postListR = [];
            
            if ~isempty(pkR)

                centR = cntrd(handles.bPassStack(:,:,2,frameNow), pkR, cntrdRad);

                postListR = [postListR; centR(:,1), centR(:,2)];

            end
            
            postListR = [postListR ones(size(postListR, 1), 1)];
            
            
            
            if handles.CenterChannel ~= 3
                for m = 1:size(postListR, 1)
                    postListR(m,3) = ctrMask((pkR(m,2)), (pkR(m,1)));
                end  
            end
            
            handles.ParticleList{2} = postListR;
            handles.pkR = pkR;
            
            if ~isempty(postListR);
                set(handles.handles.ax2, 'NextPlot', 'add');
                xmark = plot(handles.handles.ax2, handles.ParticleList{2}(handles.ParticleList{2}(:,3) == 1,1), handles.ParticleList{2}(handles.ParticleList{2}(:,3) == 1,2), 'rx');
                dotmark = plot(handles.handles.ax2, handles.ParticleList{2}(handles.ParticleList{2}(:,3) == 0,1), handles.ParticleList{2}(handles.ParticleList{2}(:,3) == 0,2), 'rs', 'markerFaceColor', 'r', 'markerSize', 3);
                set(xmark, 'hittest', 'off');
                set(dotmark, 'hittest', 'off');
                set(handles.handles.ax2, 'NextPlot', 'replace');
            end
            
        end
        
        guidata(handles.handles.fig1, handles);
        
    end
    
%%%%%%%%%%%%%%%%%%%%%%
% Create user-defined ROIs for all frames
% Done once when 'U' Channel Center intensity button selected

    function setUpUserDefinedCenterROIs()
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        
        handles.UserDefinedCenterROIs = cell(handles.N_frames, 1);
        
        % Start with current frame
        currPoly = impoly(handles.handles.ax1);
        currPoly.setColor('m');
        currPoly.setClosed(true);
        currPoly.addNewPositionCallback(@roiPolyUpdate);
        fcn = makeConstrainToRectFcn('impoly', get(gca,'XLim'), get(gca,'YLim'));
        currPoly.setPositionConstraintFcn(fcn);

        % User now inputs ROI

        % Copy this prototype to every frame in the image
        for m = 1:handles.N_frames
            handles.UserDefinedCenterROIs{m} = currPoly.getPosition();
        end
    
        guidata(handles.handles.fig1, handles);
        
    end

    function roiPolyUpdate(varargin)
        
        handles = guidata(findobj('Tag', 'TIFF viewer'));
        currFrame = str2double(handles.handles.slide_box.String());        
         currPoly = iptgetapi(findobj('parent', handles.handles.ax1, 'tag', 'impoly'));
         handles.UserDefinedCenterROIs{currFrame} = currPoly.getPosition();
         
         delete(findobj('parent', handles.handles.ax2, 'color', 'm'));
         set(handles.handles.ax2, 'nextplot', 'add');
         plot(handles.handles.ax2, handles.UserDefinedCenterROIs{currFrame}([1:end 1], 1), ...
             handles.UserDefinedCenterROIs{currFrame}([1:end 1], 2), 'm');
         
         guidata(handles.handles.fig1, handles);
         calculateDetectedParticles('both');
         
         
               
    end

%%%%%%%%%%%%%%%%%%%%%%
% Set parameters for image display

    function Image_prefs(varargin)
        
        % Make sure there isn't another one of these already open.  If so,
        % bring it to the front.  
        
        if ~isempty(findobj('Tag', 'GALAH_Image_prefs'))
        
            uistack(findobj('Tag', 'GALAH_Image_prefs'), 'top');
            
        else
            
            %fig1 = findobj('Tag', 'TIFF viewer');
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            mf_post = get(findobj('Tag', 'TIFF viewer'), 'Position').*([handles.scrsz_pixels(3) handles.scrsz_pixels(4) handles.scrsz_pixels(3) handles.scrsz_pixels(4)]);      
            fig2_size = [400 300];
            fig2_position = [(mf_post(1) + (mf_post(3) - fig2_size(1))/2) (mf_post(2) + (mf_post(4) - fig2_size(2))/2)];
            fig2 = figure('Name','Image Preferences', 'Tag', 'GALAH_Image_prefs', 'Units', 'pixels',...
                'Position',[fig2_position fig2_size], 'NumberTitle', 'off', 'Toolbar', 'none', 'Menu', 'none');
            set(fig2, 'Color',[0.9 0.9 0.9]);

            fig2_green = uipanel(fig2, 'Units', 'normalized', 'Position', [0 .45, 1, .44], ...
                'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'green_panel', 'Title', 'Channel 1');

            fig2_red = uipanel(fig2, 'Units', 'normalized', 'Position', [0 0, 1, .44], ...
                'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'etchedin', 'Tag', 'red_panel', 'Title', 'Channel 2');

            fig2_top = uipanel(fig2, 'Units', 'normalized', 'Position', [0 .89, 1, .11], ...
                'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'none', 'Tag', 'top_panel');

            handles.handles.fig2_green = fig2_green;
            handles.handles.fig2_red = fig2_red;
            handles.handles.fig2_top = fig2_top;

            %%%%%%%%%%%%%%%%%%
            % Single/dual channel toggle

            dual_single_radio = uibuttongroup('visible', 'off', 'Parent', fig2_top, 'Units', 'normalized', ...
                'Position', [0 0 1 1], 'BorderType', 'none', 'BackgroundColor', [.9 .9 .9]);
            ds1 = uicontrol('Style', 'togglebutton', 'String', 'Single Channel', 'Parent', dual_single_radio, ...
                'Units', 'normalized', 'Position', [.05 .05 .4 .9]);
            ds2 = uicontrol('Style', 'togglebutton', 'String', 'Dual Channel', 'Parent', dual_single_radio, ...
                'Units', 'normalized', 'Position', [.55 .05 .4 .9]);
            set(dual_single_radio, 'SelectionChangeFcn', @dual_single_push);
            radio_handles = [ds1 ds2];
            set(dual_single_radio, 'SelectedObject', radio_handles(handles.N_channels));
            set(dual_single_radio, 'Visible', 'on');
            
            handles.handles.dual_single_radio.Single = ds1;
            handles.handles.dual_single_radio.Dual = ds2;
            handles.handles.dual_slingle_radio = dual_single_radio;

            %%%%%%%%%%%%%%%%%%
            % Channel 1 (green channel) sliders and such
            
             if isempty(handles.Load_file)
                 
                slider_step = 1;
                green_range = [0 1];
                green_max_slider_display = 1;
                green_min_slider_display = 0;
                slider_value_green_max = 1;
                slider_value_green_min = 0;
                
             elseif ~isempty(handles.Load_file)

                green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];

                slider_value_green_max = (handles.Display_range_left(2) - green_range(1))/(green_range(2) - green_range(1));
                slider_step = 1/((green_range(2)-green_range(1))-1);
                
                slider_value_green_min = (handles.Display_range_left(1) - green_range(1))/(green_range(2) - green_range(1));
                slider_step = 1/((green_range(2)-green_range(1))-1);
                
             end

            green_max_slide_hand = uicontrol(fig2_green, 'Style', 'slider', 'Units', 'normalized',...  
                'SliderStep', [slider_step slider_step], 'Min', 0, 'Max', 1, 'Value', slider_value_green_max, 'Position', [.30 .77 .68 .1],...
                'Callback', @slider_green_max_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'Green max');

            green_max_slide_listen = addlistener(green_max_slide_hand, 'Value', 'PostSet', @slider_green_max_listener);

            green_max_slide_box = uicontrol(fig2_green, 'Style', 'edit', 'Units', 'normalized', ...
                'Position', [.18 .71 .1 .25], 'BackgroundColor', [1 1 1], ...
                'String', num2str(handles.Display_range_left(2)), 'Callback', @edit_green_max_call);

            green_max_slide_text = uicontrol(fig2_green, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .75 .16 .14], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Display Max:');

            set(green_max_slide_hand, 'Enable', 'off');
            set(green_max_slide_box, 'Enable', 'off');

            green_min_slide_hand = uicontrol(fig2_green, 'Style', 'slider', 'Units', 'normalized',...  
                'SliderStep', [slider_step slider_step], 'Min', 0, 'Max', 1, 'Value', slider_value_green_min, 'Position', [.3 .46 .68 .1],...
                'Callback', @slider_green_min_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'Green max');

            green_min_slide_listen = addlistener(green_min_slide_hand, 'Value', 'PostSet', @slider_green_min_listener);

            green_min_slide_box = uicontrol(fig2_green, 'Style', 'edit', 'Units', 'normalized', ...
                'Position', [.18 .39 .1 .25], 'BackgroundColor', [1 1 1], ...
                'String', num2str(handles.Display_range_left(1)), 'Callback', @edit_green_min_call);

            green_min_slide_text = uicontrol(fig2_green, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .43 .16 .14], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Display Min:');

            Colormap_strings = {'Gray'; 'Jet'; 'Green'; 'Red'; 'Cyan'; 'Yellow'; 'Hot'; 'Cool'; 'Spring'; 'Summer'; 'Autumn'; 'Winter'};
            handles.Colormap_strings = Colormap_strings;
            left_value = find(strcmpi(handles.Left_color, Colormap_strings));

            green_colormap_listbox = uicontrol(fig2_green, 'Style', 'popupmenu', 'Units', 'normalized', ...
                'Position', [.18 .095 .22 .2], 'String', Colormap_strings, 'Value', left_value, 'Callback', @popup_green_colormap);

            green_colormap_text = uicontrol(fig2_green, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .05 .16 .2], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Colormap:');

            green_autoscale = uicontrol('Style', 'checkbox', 'String', 'Autoscale', 'Parent', fig2_green, ...
                'Units', 'normalized', 'Position', [.50 .06 .2 .25], 'BackgroundColor', [.9 .9 .9], ...
                'Value', handles.Autoscale_left, 'Callback', @autoscale_green);

            green_invert = uicontrol('Style', 'checkbox', 'String', 'Invert Image', 'Parent', fig2_green, ...
                'Units', 'normalized', 'Position', [.76 .06 .2 .25], 'BackgroundColor', [.9 .9 .9], ...
                'Value', handles.Left_invert, 'Callback', @invert_green);

            if handles.Autoscale_left == 1
                set(green_max_slide_hand, 'Enable', 'off');
                set(green_max_slide_box, 'Enable', 'off');
                set(green_min_slide_hand, 'Enable', 'off');
                set(green_min_slide_box, 'Enable', 'off');
            else
                set(green_max_slide_hand, 'Enable', 'on');
                set(green_max_slide_box, 'Enable', 'on');
                set(green_min_slide_hand, 'Enable', 'on');
                set(green_min_slide_box, 'Enable', 'on');
            end
            set(green_colormap_listbox, 'Enable', 'on');

            %%%%%%%%%%%%%%%%%%
            % Channel 2 (red channel) sliders and such
            
            if isempty(handles.Load_file)
                red_range = [0 1];
                slider_step = 1;
                red_max_slider_display = 1;
                red_min_slider_display = 0;
                slider_value_red_max = 1;
                slider_value_red_min = 0;
                
            else

                if handles.N_channels == 2
                    red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
                    slider_step = 1/((red_range(2)-red_range(1))-1);
                    red_max_slider_display = handles.Display_range_right(2);
                    red_min_slider_display = handles.Display_range_right(1);
                    slider_value_red_max = (handles.Display_range_right(2) - red_range(1))/(red_range(2) - red_range(1));
                    slider_value_red_min = (handles.Display_range_right(1) - red_range(1))/(red_range(2) - red_range(1));
                else
                    slider_step = 1;
                    red_range = [0 1];
                    red_max_slider_display = 1;
                    red_min_slider_display = 0;
                    slider_value_red_max = 1;
                    slider_value_red_min = 0;
                end
                
            end

            red_max_slide_hand = uicontrol(fig2_red, 'Style', 'slider', 'Units', 'normalized',...  
                'SliderStep', [slider_step slider_step], 'Min', 0, 'Max', 1, 'Value', slider_value_red_max, 'Position', [.30 .77 .68 .1],...
                'Callback', @slider_red_max_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'red max');

            red_max_slide_listen = addlistener(red_max_slide_hand, 'Value', 'PostSet', @slider_red_max_listener);

            red_max_slide_box = uicontrol(fig2_red, 'Style', 'edit', 'Units', 'normalized', ...
                'Position', [.18 .71 .1 .25], 'BackgroundColor', [1 1 1], ...
                'String', num2str(red_max_slider_display), 'Callback', @edit_red_max_call);

            red_max_slide_text = uicontrol(fig2_red, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .75 .16 .14], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Display Max:');

            set(red_max_slide_hand, 'Enable', 'off');
            set(red_max_slide_box, 'Enable', 'off');

            

            red_min_slide_hand = uicontrol(fig2_red, 'Style', 'slider', 'Units', 'normalized',...  
                'SliderStep', [slider_step slider_step], 'Min', 0, 'Max', 1, 'Value', slider_value_red_min, 'Position', [.3 .46 .68 .1],...
                'Callback', @slider_red_min_call, 'BackgroundColor', [.6 .6 .6], 'Tag', 'red max');

            red_min_slide_listen = addlistener(red_min_slide_hand, 'Value', 'PostSet', @slider_red_min_listener);

            red_min_slide_box = uicontrol(fig2_red, 'Style', 'edit', 'Units', 'normalized', ...
                'Position', [.18 .39 .1 .25], 'BackgroundColor', [1 1 1], ...
                'String', num2str(red_min_slider_display), 'Callback', @edit_red_min_call);

            red_min_slide_text = uicontrol(fig2_red, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .43 .16 .14], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Display Min:');

            right_value = find(strcmpi(handles.Right_color, Colormap_strings));

            red_colormap_listbox = uicontrol(fig2_red, 'Style', 'popupmenu', 'Units', 'normalized', ...
                'Position', [.18 .095 .22 .2], 'String', Colormap_strings, 'Value', right_value, 'Callback', @popup_red_colormap);

            red_colormap_text = uicontrol(fig2_red, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [.01 .05 .16 .2], 'BackgroundColor', [.9 .9 .9], ...
                'String', 'Colormap:');

            red_autoscale = uicontrol('Style', 'checkbox', 'String', 'Autoscale', 'Parent', fig2_red, ...
                'Units', 'normalized', 'Position', [.50 .06 .2 .25], 'BackgroundColor', [.9 .9 .9], ...
                'Value', handles.Autoscale_right, 'Callback', @autoscale_red);

            red_invert = uicontrol('Style', 'checkbox', 'String', 'Invert Image', 'Parent', fig2_red, ...
                'Units', 'normalized', 'Position', [.76 .06 .2 .25], 'BackgroundColor', [.9 .9 .9], ...
                'Value', handles.Right_invert, 'Callback', @invert_red);
            


            if handles.Autoscale_left == 1;
                set(green_max_slide_hand, 'Enable', 'off');
                set(green_max_slide_box, 'Enable', 'off');
                set(green_min_slide_hand, 'Enable', 'off');
                set(green_min_slide_box, 'Enable', 'off');
                set(green_min_slide_text, 'Enable', 'off');
                set(green_max_slide_text, 'Enable', 'off');
            else
                set(green_max_slide_hand, 'Enable', 'on');
                set(green_max_slide_box, 'Enable', 'on');
                set(green_min_slide_hand, 'Enable', 'on');
                set(green_min_slide_box, 'Enable', 'on');
                set(green_min_slide_text, 'Enable', 'on');
                set(green_max_slide_text, 'Enable', 'on');
            end

            set(red_colormap_listbox, 'Enable', 'on');

            if handles.Autoscale_right == 1;
                set(red_max_slide_hand, 'Enable', 'off');
                set(red_max_slide_box, 'Enable', 'off');
                set(red_min_slide_hand, 'Enable', 'off');
                set(red_min_slide_box, 'Enable', 'off');
                set(red_min_slide_text, 'Enable', 'off');
                set(red_max_slide_text, 'Enable', 'off');
            else
                set(red_max_slide_hand, 'Enable', 'on');
                set(red_max_slide_box, 'Enable', 'on');
                set(red_min_slide_hand, 'Enable', 'on');
                set(red_min_slide_box, 'Enable', 'on');
                set(red_min_slide_text, 'Enable', 'on');
                set(red_max_slide_text, 'Enable', 'on');
            end
            
            if handles.N_channels == 1;
                
                set(red_max_slide_hand, 'Enable', 'off');
                set(red_max_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_hand, 'Enable', 'off');
                set(red_min_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_text, 'Enable', 'off');
                set(red_max_slide_text, 'Enable', 'off');
                set(red_autoscale, 'Enable', 'off');
                set(red_invert, 'Enable', 'off');
                set(red_colormap_listbox, 'Enable', 'off');
                set(red_colormap_text, 'Enable', 'off');
                
            end
            
            if isempty(handles.Load_file)
                
                set(green_max_slide_hand, 'Enable', 'off');
                set(green_max_slide_box, 'Enable', 'off', 'String', []);
                set(green_min_slide_hand, 'Enable', 'off');
                set(green_min_slide_box, 'Enable', 'off', 'String', []);
                set(green_min_slide_text, 'Enable', 'off');
                set(green_max_slide_text, 'Enable', 'off');
                set(green_autoscale, 'Enable', 'off');

                set(red_max_slide_hand, 'Enable', 'off');
                set(red_max_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_hand, 'Enable', 'off');
                set(red_min_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_text, 'Enable', 'off');
                set(red_max_slide_text, 'Enable', 'off');
                set(red_autoscale, 'Enable', 'off');
                
            end
            
            if mod(handles.N_frames*handles.N_channels,2) == 1
                set(handles.handles.dual_single_radio.Single, 'Enable', 'off')
                set(handles.handles.dual_single_radio.Dual, 'Enable', 'off')
            end
            
            handles.handles.green_max_slide_hand = green_max_slide_hand;
            handles.handles.green_max_slide_box = green_max_slide_box;
            handles.handles.green_min_slide_hand = green_min_slide_hand;
            handles.handles.green_min_slide_box = green_min_slide_box;
            handles.handles.green_colormap_listbox = green_colormap_listbox;
            handles.handles.green_autoscale = green_autoscale;
            handles.handles.green_invert = green_invert;
            
            handles.handles.red_max_slide_hand = red_max_slide_hand;
            handles.handles.red_max_slide_box = red_max_slide_box;
            handles.handles.red_min_slide_hand = red_min_slide_box;
            handles.handles.red_min_slide_box = red_max_slide_box;
            handles.handles.red_colormap_listbox = red_colormap_listbox;
            handles.handles.red_autoscale = red_autoscale;
            handles.handles.red_invert = red_invert;
            

            guidata(findobj('Tag', 'TIFF viewer'), handles);
        end
            %%%% Big pile of callback functions

        function dual_single_push(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            
            channels_now = find(eventdata.NewValue == [handles.handles.dual_single_radio.Single handles.handles.dual_single_radio.Dual]);
            %disp(channels_now);
            
            if handles.N_frames*handles.N_channels == 1;
                
                % If there is only one frame, it can only be a
                % single-channel data set.  This forces that fact. 
                % There shouldn't ever be anything to change as the
                % single-frame/single-channel issue is addressed upon
                % loading.
                
                channels_now = 3;
                set(handles.handles.dual_slingle_radio, 'SelectedObject', handles.handles.dual_single_radio.Single);
                
                
            end
            
            if channels_now == 1;
            	handles.N_channels = 1;
            
                % Disable all of right channel
                
                set(red_max_slide_hand, 'Enable', 'off');
                set(red_max_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_hand, 'Enable', 'off');
                set(red_min_slide_box, 'Enable', 'off', 'String', []);
                set(red_min_slide_text, 'Enable', 'off');
                set(red_max_slide_text, 'Enable', 'off');
                set(red_autoscale, 'Enable', 'off');
                set(red_invert, 'Enable', 'off');
                set(red_colormap_listbox, 'Enable', 'off');
                set(red_colormap_text, 'Enable', 'off');

                if ~isempty(handles.Load_file)
                    
                    % Collapse Img_stack, Min_max_XXX down to a single dimension

                    green_frames = 1:2:(handles.N_frames*2);
                    red_frames = 2:2:(handles.N_frames*2);

                    Img_hold = zeros(size(handles.Img_stack,1), size(handles.Img_stack,2), 2*handles.N_channels, 1);
                    Img_hold(:,:,green_frames) = handles.Img_stack(:,:,:,1);
                    Img_hold(:,:,red_frames) = handles.Img_stack(:,:,:,2);

                    Min_max_hold = zeros(handles.N_frames, 2);
                    Min_max_hold(green_frames, :) = handles.Min_max_left;
                    Min_max_hold(red_frames, :) = handles.Min_max_right;

                    handles.Img_stack = Img_hold;
                    handles.Min_max_left = Min_max_hold;
                    handles.Min_max_right = [];
                    clear Img_hold Min_max_hold;

                    handles.N_frames = size(handles.Img_stack, 3);

                    if handles.Primary_channel > handles.N_channels
                        handles.Primary_channel = handles.N_channels;
                    end


                    % Figure out where slider should be with new N_channels

                    slider_step = 1/(handles.N_frames-1);

                    if handles.N_frames == 1;
                        set(slide_hand, 'SliderStep', [1 1]);
                    else
                        set(slide_hand, 'SliderStep', [1/(handles.N_frames-1) 1/(handles.N_frames-1)]);
                    end 
                    
                    set(slide_box, 'String', (1 + round((handles.N_frames - 1)*(get(slide_hand, 'Value')))));

                    green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
                    slider_step_green = 1/((green_range(2)-green_range(1))-1);

                    green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
                    slider_step_green = 1/((green_range(2)-green_range(1))-1);



                    set(green_max_slide_hand, 'SliderStep', [slider_step_green slider_step_green]);
                    set(green_min_slide_hand, 'SliderStep', [slider_step_green slider_step_green]); 

                    slide_string_max = str2num(get(green_max_slide_box, 'String'));
                    slide_set_max = ((slide_string_max - green_range(1))/(green_range(2) - green_range(1)));
                    slide_set_max = min([slide_set_max 1]); 
                    slider_value_max = (green_range(1) + slide_set_max*(green_range(2) - green_range(1)));
                    set(green_max_slide_box, 'String', num2str(slider_value_max));
                    set(green_max_slide_hand, 'Value', slide_set_max);

                    slide_string_min = str2num(get(green_min_slide_box, 'String'));
                    slide_set_min = ((slide_string_min - green_range(1))/(green_range(2) - green_range(1)));
                    slide_set_min = max([slide_set_min 0]);
                    slider_value_min = (green_range(1) + slide_set_min*(green_range(2) - green_range(1)));
                    set(green_min_slide_box, 'String', num2str(slider_value_min));
                    set(green_min_slide_hand, 'Value', slide_set_min);


                    % Fill in red channel with dummy image
                    path_here = mfilename('fullpath');
                    logo_file = fullfile(fileparts(path_here), 'BMIF_logo.jpg');

                    %disp(logo_file);

                    ax2 = handles.handles.ax2;

                    if exist(logo_file, 'file') == 2;

                        logo_hold = single(imread(logo_file));
                        logo_2 = logo_hold(:,:,1);
                        clear logo_hold
                        %disp(size(logo_2));
                        fill_image = imagesc(Vector2Colormap(-logo_2,handles.Right_color), 'Parent', ax2);
                        set(fill_image, 'Tag', 'fill_image_right', 'HitTest', 'on');

                    else

                        % Dummy data to put into the axes on startup
                        z=peaks(1000);
                        z = z./max(abs(z(:)));
                        fill_image = imshow(z, 'Parent', ax2, 'ColorMap', jet, 'DisplayRange', [min(z(:)) max(z(:))]);
                        set(fill_image, 'Tag', 'fill_image_right', 'HitTest', 'on');
                        freezeColors(ax2);

                    end

                    % Get rid of tick labels
                    set(ax2, 'xtick', [], 'ytick', []);

                    guidata(findobj('Tag', 'TIFF viewer'), handles);

                    Display_images_in_axes;
                    
                else
                    
                    guidata(findobj('Tag', 'TIFF viewer'), handles);
                
                end
                
            elseif channels_now == 2;
                handles.N_channels = 2;
                
                if ~isempty(handles.Load_file)
                
                % Enable right channel
                
                set(red_max_slide_hand, 'Enable', 'on');
                set(red_max_slide_box, 'Enable', 'on');
                set(red_min_slide_hand, 'Enable', 'on');
                set(red_min_slide_box, 'Enable', 'on');
                set(red_min_slide_text, 'Enable', 'on');
                set(red_max_slide_text, 'Enable', 'on');
                set(red_autoscale, 'Enable', 'on');
                set(red_invert, 'Enable', 'on');
                set(red_colormap_listbox, 'Enable', 'on');
                set(red_colormap_text, 'Enable', 'on');
                
                % Expand Img_stack to two channels
        
                    green_frames = 1:2:(handles.N_frames);
                    red_frames = 2:2:(handles.N_frames);

                    Img_hold = zeros(size(handles.Img_stack,1), size(handles.Img_stack,2), handles.N_frames/2, 2);
                    Img_hold(:,:,:,1) = handles.Img_stack(:,:,green_frames);
                    Img_hold(:,:,:,2) = handles.Img_stack(:,:,red_frames);

                    Min_max_hold_left = zeros(handles.N_frames, 2);
                    Min_max_hold_right = zeros(handles.N_frames, 2);
                    Min_max_hold_left = handles.Min_max_left(green_frames, :);
                    Min_max_hold_right = handles.Min_max_left(red_frames, :);

                    handles.Min_max_left = Min_max_hold_left;
                    handles.Min_max_right = Min_max_hold_right;
                    handles.Img_stack = Img_hold;
                    clear Img_hold Min_max_hold_left Min_max_hold_right

                    handles.N_frames = size(handles.Img_stack, 3);

                    if handles.Primary_channel > handles.N_channels
                        handles.Primary_channel = handles.N_channels;
                    end

                    % Figure out where sliders should be with new N_channels

                    slider_step = 1/(handles.N_frames-1);
                    slide_hand = handles.handles.slide_hand;
                    slide_box = handles.handles.slide_box;
                    
                    if handles.N_frames == 1;
                        set(slide_hand, 'SliderStep', [1 1]);
                    
                    else
                        set(slide_hand, 'SliderStep', [1/(handles.N_frames-1) 1/(handles.N_frames-1)]);
                    end
                    
                    set(slide_box, 'String', (1 + round((handles.N_frames - 1)*(get(slide_hand, 'Value')))));

                    green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
                    slider_step_green = 1/((green_range(2)-green_range(1))-1);

                    set(green_max_slide_hand, 'SliderStep', [slider_step_green slider_step_green]);
                    set(green_min_slide_hand, 'SliderStep', [slider_step_green slider_step_green]);

                    slide_string_max = str2num(get(green_max_slide_box, 'String'));
                    slide_set_max = ((slide_string_max - green_range(1))/(green_range(2) - green_range(1)));
                    slide_set_max = min([slide_set_max 1]); 
                    slider_value_max = (green_range(1) + slide_set_max*(green_range(2) - green_range(1)));
                    set(green_max_slide_box, 'String', num2str(slider_value_max));
                    set(green_max_slide_hand, 'Value', slide_set_max);

                    slide_string_min = str2num(get(green_min_slide_box, 'String'));
                    slide_set_min = ((slide_string_min - green_range(1))/(green_range(2) - green_range(1)));
                    slide_set_min = max([slide_set_min 0]); 
                    slider_value_min = (green_range(1) + slide_set_min*(green_range(2) - green_range(1)));
                    set(green_min_slide_box, 'String', num2str(slider_value_min));
                    set(green_min_slide_hand, 'Value', slide_set_min);


                    red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
                    slider_step_red = 1/((red_range(2)-red_range(1))-1);
                    set(red_max_slide_hand, 'SliderStep', [slider_step_red slider_step_red]);
                    set(red_min_slide_hand, 'SliderStep', [slider_step_red slider_step_red]);
                    set(red_max_slide_box, 'String', num2str(handles.Display_range_right(2)));
                    set(red_min_slide_box, 'String', num2str(handles.Display_range_right(1)));

                    % Replot channels
                    
                    NewXLim = [0.5 size(handles.Img_stack, 2)+0.5];
                    NewYLim = [0.5 size(handles.Img_stack, 1)+0.5];
                    set(handles.handles.ax2, 'XLim', NewXLim, 'YLim', NewYLim);


                    guidata(findobj('Tag', 'TIFF viewer'), handles);
                    Display_images_in_axes;
                    
                else
                    
                    set(red_invert, 'Enable', 'on');
                    set(red_colormap_listbox, 'Enable', 'on');
                    set(red_colormap_text, 'Enable', 'on');
                    
                   guidata(findobj('Tag', 'TIFF viewer'), handles); 
                
                end
            
            end
            
                    if handles.N_frames == 1
                        set(handles.handles.Unbind_out, 'Enable', 'off');
                        set(handles.handles.ExpFit_out, 'Enable', 'off');
                        set(slide_hand, 'Enable', 'off')
                        set(slide_box, 'Enable', 'off')
                    else
                        set(handles.handles.Unbind_out, 'Enable', 'on');
                        set(handles.handles.ExpFit_out, 'Enable', 'on');
                        set(slide_hand, 'Enable', 'on')
                        set(slide_box, 'Enable', 'on')
                        
                    end

        end

        function slider_green_max_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_green_here = get(green_max_slide_hand, 'Value');
            slider_check_here = get(green_min_slide_hand, 'Value');
            slider_step = get(green_max_slide_hand, 'SliderStep');
            
            if le(slider_green_here, slider_check_here)
                %disp('slider_check');
                slider_green_here = slider_check_here + slider_step(1);
                set(green_max_slide_hand, 'Value', slider_green_here);
            end    
            
            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            slider_value = round(slider_green_here*(green_range(2) - green_range(1)) + green_range(1));
            
            set(green_max_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_left(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
            
            
            

        end

        function slider_green_max_listener(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_green_here = get(green_max_slide_hand, 'Value');
            slider_check_here = get(green_min_slide_hand, 'Value');
            slider_step = get(green_max_slide_hand, 'SliderStep');
            
            if le(slider_green_here, slider_check_here)
                %disp('slider_check');
                slider_green_here = slider_check_here + slider_step(1);
                set(green_max_slide_hand, 'Value', slider_green_here);
            end 
            
            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            slider_value = round(slider_green_here*(green_range(2) - green_range(1)) + green_range(1));
            
            set(green_max_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_left(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
        
        end

        function edit_green_max_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slide_string = str2num(get(green_max_slide_box, 'String'));
            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            
            if length(slide_string) ~= 1
                slide_set = get(green_max_slide_hand, 'Value');
                slide_str2 = round(green_range(2)+slide_set*(green_range(2) - green_range(1)));
            
            else
        
            slide_set = ((slide_string - green_range(1))/(green_range(2) - green_range(1)));
            slide_range = [get(green_max_slide_hand, 'Min') get(green_max_slide_hand, 'Max')];

                if slide_set > slide_range(2)

                    slide_set = slide_range(2);
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));

                elseif slide_set < slide_range(1)

                    slide_set = slide_range(1);
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));
                    
                else 
                    
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));

                end
        
            end
            
            
            slider_value = slide_str2;
            
            set(green_max_slide_box, 'String', num2str(slider_value));
            set(green_max_slide_hand, 'Value', slide_set);
            
            handles.Display_range_left(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
     
        end

        function slider_green_min_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_green_here = get(green_min_slide_hand, 'Value');
            slider_check_here = get(green_max_slide_hand, 'Value');
            slider_step = get(green_min_slide_hand, 'SliderStep');
            
            if ge(slider_green_here, slider_check_here)
                %disp('slider_check');
                slider_green_here = slider_check_here - slider_step(1);
                set(green_min_slide_hand, 'Value', slider_green_here);
            end 
            

            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            slider_value = round(slider_green_here*(green_range(2) - green_range(1)) + green_range(1));
            
            set(green_min_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_left(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
            

        end

        function slider_green_min_listener(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_green_here = get(green_min_slide_hand, 'Value');
            slider_check_here = get(green_max_slide_hand, 'Value');
            slider_step = get(green_min_slide_hand, 'SliderStep');
            
            if ge(slider_green_here, slider_check_here)
                %disp('slider_check');
                slider_green_here = slider_check_here - slider_step(1);
                set(green_min_slide_hand, 'Value', slider_green_here);
            end 
            
            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            slider_value = round(slider_green_here*(green_range(2) - green_range(1)) + green_range(1));
            
            set(green_min_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_left(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
        
        end

        function edit_green_min_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slide_string = str2num(get(green_min_slide_box, 'String'));
            green_range = [min(handles.Min_max_left(:,1)), max(handles.Min_max_left(:,2))];
            
            if length(slide_string) ~= 1
                slide_set = get(green_max_slide_hand, 'Value');
                slide_str2 = round(green_range(2)+slide_set*(green_range(2) - green_range(1)));
            
            else
        
            slide_set = ((slide_string - green_range(1))/(green_range(2) - green_range(1)));
            slide_range = [get(green_max_slide_hand, 'Min') get(green_max_slide_hand, 'Max')];

                if slide_set > slide_range(2)

                    slide_set = slide_range(2);
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));

                elseif slide_set < slide_range(1)

                    slide_set = slide_range(1);
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));
                    
                else 
                    
                    slide_str2 = (green_range(1) + slide_set*(green_range(2) - green_range(1)));

                end
        
            end
            
            
            slider_value = slide_str2;
            
            set(green_min_slide_box, 'String', num2str(slider_value));
            set(green_min_slide_hand, 'Value', slide_set);
            
            handles.Display_range_left(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
      
        end

        function popup_green_colormap(hObj, eventdata, handles) %%%%
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            string_here = get(green_colormap_listbox, 'Value');
            handles.Left_color = lower(handles.Colormap_strings{string_here});

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function autoscale_green(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            handles.Autoscale_left = get(green_autoscale, 'Value');
            
            if handles.Autoscale_left == 1;
                set(green_max_slide_hand, 'Enable', 'off');
                set(green_max_slide_box, 'Enable', 'off');
                set(green_min_slide_hand, 'Enable', 'off');
                set(green_min_slide_box, 'Enable', 'off');
                set(green_min_slide_text, 'Enable', 'off');
                set(green_max_slide_text, 'Enable', 'off');
            else
                set(green_max_slide_hand, 'Enable', 'on');
                set(green_max_slide_box, 'Enable', 'on');
                set(green_min_slide_hand, 'Enable', 'on');
                set(green_min_slide_box, 'Enable', 'on');
                set(green_min_slide_text, 'Enable', 'on');
                set(green_max_slide_text, 'Enable', 'on');
            end

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
       
        end

        function invert_green(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            handles.Left_invert = get(green_invert, 'Value');

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function slider_red_max_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_right_here = get(red_max_slide_hand, 'Value');
            slider_check_here = get(red_min_slide_hand, 'Value');
            slider_step = get(red_max_slide_hand, 'SliderStep');
            
            if le(slider_right_here, slider_check_here)
                %disp('slider_check');
                slider_right_here = slider_check_here + slider_step(1);
                set(red_max_slide_hand, 'Value', slider_right_here);
            end 

            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            slider_value = round(slider_right_here*(red_range(2) - red_range(1)) + red_range(1));
            
            set(red_max_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_right(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function slider_red_max_listener(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_right_here = get(red_max_slide_hand, 'Value');
            slider_check_here = get(red_min_slide_hand, 'Value');
            slider_step = get(red_max_slide_hand, 'SliderStep');
            
            if le(slider_right_here, slider_check_here)
                %disp('slider_check');
                slider_right_here = slider_check_here + slider_step(1);
                set(red_max_slide_hand, 'Value', slider_right_here);
            end 
            
            
            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            slider_value = round(slider_right_here*(red_range(2) - red_range(1)) + red_range(1));
            
            set(red_max_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_right(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function edit_red_max_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slide_string = str2num(get(red_max_slide_box, 'String'));
            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            
            if length(slide_string) ~= 1
                slide_set = get(red_max_slide_hand, 'Value');
                slide_str2 = round(red_range(2)+slide_set*(red_range(2) - red_range(1)));
            
            else
        
            slide_set = ((slide_string - red_range(1))/(red_range(2) - red_range(1)));
            slide_range = [get(red_max_slide_hand, 'Min') get(red_max_slide_hand, 'Max')];

                if slide_set > slide_range(2)

                    slide_set = slide_range(2);
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));

                elseif slide_set < slide_range(1)

                    slide_set = slide_range(1);
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));
                    
                else 
                    
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));

                end
        
            end
            
            
            slider_value = slide_str2;
            
            set(red_max_slide_box, 'String', num2str(slider_value));
            set(red_max_slide_hand, 'Value', slide_set);
            
            handles.Display_range_right(2) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;          


        end

        function slider_red_min_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_right_here = get(red_min_slide_hand, 'Value');
            slider_check_here = get(red_max_slide_hand, 'Value');
            slider_step = get(red_min_slide_hand, 'SliderStep');
            
            if ge(slider_right_here, slider_check_here)
                %disp('slider_check');
                slider_right_here = slider_check_here - slider_step(1);
                set(red_min_slide_hand, 'Value', slider_right_here);
            end 
            
            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            slider_value = round(slider_right_here*(red_range(2) - red_range(1)) + red_range(1));
            
            set(red_min_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_right(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function slider_red_min_listener(hObj, eventdata, handles)
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slider_right_here = get(red_min_slide_hand, 'Value');
            slider_check_here = get(red_max_slide_hand, 'Value');
            slider_step = get(red_min_slide_hand, 'SliderStep');
            
            if ge(slider_right_here, slider_check_here)
                %disp('slider_check');
                slider_right_here = slider_check_here - slider_step(1);
                set(red_min_slide_hand, 'Value', slider_right_here);
            end 

            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            slider_value = round(slider_right_here*(red_range(2) - red_range(1)) + red_range(1));
            
            set(red_min_slide_box, 'String', num2str(slider_value));
            
            handles.Display_range_right(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
          
        end

        function edit_red_min_call(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            slide_string = str2num(get(red_min_slide_box, 'String'));
            red_range = [min(handles.Min_max_right(:,1)), max(handles.Min_max_right(:,2))];
            
            if length(slide_string) ~= 1
                slide_set = get(red_min_slide_hand, 'Value');
                slide_str2 = round(red_range(2)+slide_set*(red_range(2) - red_range(1)));
            
            else
        
            slide_set = ((slide_string - red_range(1))/(red_range(2) - red_range(1)));
            slide_range = [get(red_min_slide_hand, 'Min') get(red_min_slide_hand, 'Max')];

                if slide_set > slide_range(2)

                    slide_set = slide_range(2);
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));

                elseif slide_set < slide_range(1)

                    slide_set = slide_range(1);
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));
                    
                else 
                    
                    slide_str2 = (red_range(1) + slide_set*(red_range(2) - red_range(1)));

                end
        
            end
            
            
            slider_value = slide_str2;
            
            set(red_min_slide_box, 'String', num2str(slider_value));
            set(red_min_slide_hand, 'Value', slide_set);
            
            handles.Display_range_right(1) = slider_value;
            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
          
        end

        function popup_red_colormap(hObj, eventdata, handles) 
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            string_here = get(red_colormap_listbox, 'Value');
            handles.Right_color = lower(handles.Colormap_strings{string_here});

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;

        end

        function autoscale_red(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            handles.Autoscale_right = get(red_autoscale, 'Value');

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            
            if handles.Autoscale_right == 1;
                set(red_max_slide_hand, 'Enable', 'off');
                set(red_max_slide_box, 'Enable', 'off');
                set(red_min_slide_hand, 'Enable', 'off');
                set(red_min_slide_box, 'Enable', 'off');
                set(red_min_slide_text, 'Enable', 'off');
                set(red_max_slide_text, 'Enable', 'off');
            else
                set(red_max_slide_hand, 'Enable', 'on');
                set(red_max_slide_box, 'Enable', 'on');
                set(red_min_slide_hand, 'Enable', 'on');
                set(red_min_slide_box, 'Enable', 'on');
                set(red_min_slide_text, 'Enable', 'on');
                set(red_max_slide_text, 'Enable', 'on');
            end
            
            Display_images_in_axes;

        end
        
        function invert_red(hObj, eventdata, handles)
            
            handles = guidata(findobj('Tag', 'TIFF viewer'));
            handles.Right_invert = get(red_invert, 'Value');

            guidata(findobj('Tag', 'TIFF viewer'), handles);
            Display_images_in_axes;
           
        end
        
        
        
    end

    function GUI_close_fcn(varargin)
        %
    end

end


