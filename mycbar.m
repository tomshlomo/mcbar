classdef mycbar < handle
    %add checkbox for include/disinclude outliers?
    %write autocompute limits algorithm / algorithms
    %add buttons for #autotune1 #autotune2 ... (general buttons)
    %add button for selecting colormaps (general button)
    %think about additional buttons to histogram / CDF cases
    
    properties
        axes %axes of the colorbar
        data %data for the colorbar limits
        limits %limits of the colorbar
        cbar %colorbar handle
        fig_panel = [] %handle of the control panel
        h %handles of objects inside main panel
        h_controller %handles of objects inside controller panel
        
        current_control = 'Histogram'; %current control method

    end
    
    properties (Constant)
        control_menu_list = {'CDF','Histogram'};
%         default_control = 'CDF';
    end
    
    methods
        
        %constructor function
        function this = mycbar(axes,data)
            
            %handle inputs and configure axes and data
            if nargin<1
                this.axes = gca;
                this.data = [];
                for i = 1:length(this.axes.Children)
                    if isprop(this.axes.Children(i),'CData')
                        this.data = [this.data; this.axes.Children(i).CData(:)];
                    end
                end
            elseif nargin == 1
                if isa(axes,'matlab.graphics.axis.Axes')
                    this.axes = axes;
                    this.data = [];
                    for i = 1:length(this.axes.Children)
                        if isprop(this.axes.Children(i),'CData')
                            this.data = [this.data; this.axes.Children(i).CData(:)];
                        end
                    end
                else
                    this.axes = gca;
                    this.data = axes;
                end
            else
                if ~isa(axes,'matlab.graphics.axis.Axes')
                    error('First input must be axes!');
                else
                    this.axes = axes;
                    this.data = data;
                end
            end
            this.data = this.data(:); %make sure data is a long vector
            
            %open colorbar and set callback
            this.cbar = colorbar(this.axes);
            this.limits = this.axes.CLim;
            this.cbar.ButtonDownFcn = @(src,evnt) this.cbar_click_callback(src,evnt);
            
            %autocompute limits
            this.autocompute_limits_min_max();
            
        end
        
        %click colorbar callback
        function cbar_click_callback(this,src,evnt)
            
            %in case panel is not open - load figure and get handles
            if isempty(this.fig_panel) || ~ishandle(this.fig_panel)
                [this.fig_panel,this.h] = guide2fig('mycbar_mainpanel.fig','WindowStyle','normal','Name','My Colorbar - Limits Controller',...
                                                    'NumberTitle','off','MenuBar','none','ToolBar', 'none');
                this.config_panel();
%                 this.panel.DeleteFcn = @(src,evnt) delete(this);
            end

        end
        
        %configure panel
        function config_panel(this)
            %set options menu
            this.h.panel_menu.String = this.control_menu_list;
            this.h.panel_menu.Callback = @(src,evnt) setfield(this,'current_control',this.control_menu_list{this.h.panel_menu.Value});

            %set default control option
            this.h.panel_menu.Value = find(strcmp(this.current_control,this.control_menu_list));
            this.current_control = this.current_control;
            
            %config buttons
            this.h.button_autoset_minmax.Callback = @(src,evnt) this.autocompute_limits_min_max();
            this.h.button_autoset_prctile.Callback = @(src,evnt) this.autocompute_limits_5_95();
        end
        
        %set current control method
        function set.current_control(this,value)
            this.current_control = value;
            switch(value)
                case 'CDF'
                    this.init_control_CDF();
                case 'Histogram'
                    this.init_control_Histogram();
            end
        end
        
        %autocompute limits with prctile min-max (filtering outliers)
        function autocompute_limits_min_max(this)
            data_filtered = this.data(~isoutlier(this.data));
            this.limits = [min(data_filtered),max(data_filtered)];
        end
        
        %autocompute limits with prctile 5-95 (filtering outliers)
        function autocompute_limits_5_95(this)
            data_filtered = this.data(~isoutlier(this.data));
            this.limits = [prctile(data_filtered,5),prctile(data_filtered,95)];
        end
        
        %update limits method
        function set.limits(this,value)
            if value(1) == value(2)
                if min(this.data) == max(this.data)
                    error('Input data has only one value!');
                else
                    warning('Setting limits failed. Setting to minimum and maximum of input data');
                    value(1) = min(this.data);
                    value(2) = max(this.data);
                end
            end
            this.limits = value;
            this.axes.CLim = value;
            
            %update graphics (??? pretty ugly like this)
            if ~isempty(this.h_controller)
                this.h_controller.main_axes.UserData();
            end
        end
        
        %init control "CDF"
        function init_control_CDF(this)
            
            %clean graphics
            delete(this.h.panel_controller.Children);
            
            %load graphics
            [~,this.h_controller] = guide2fig('controller_CDF.fig',this.h.panel_controller);
            
            %plot CDF
            ecdf(this.h_controller.main_axes,this.data);
            this.h_controller.main_axes.Children.LineWidth = 1.5;
            grid on;
            xlims = this.h_controller.main_axes.XLim;
            ylims = this.h_controller.main_axes.YLim;
            eps_x = (xlims(2)-xlims(1)) / 1e5; %minimal delta in x axis
            
            %wire buttons
%             this.h_controller.button_morebins.Callback = @(src,evnt) morebins_button_callback(h_cdf);
%             this.h_controller.button_lessbins.Callback = @(src,evnt) lessbins_button_callback(h_cdf);
            
            %set limits
            line_left = drawline(this.h_controller.main_axes,'Position',[this.limits(1) ylims(1); this.limits(1) ylims(2)],'Color','red','InteractionsAllowed','translate',...
                'Deletable',false,'DrawingArea',[xlims(1),ylims(1),this.limits(2)-xlims(1)-eps_x,ylims(2)-ylims(1)]);
            line_right = drawline(this.h_controller.main_axes,'Position',[this.limits(2) ylims(1); this.limits(2) ylims(2)],'Color','red','InteractionsAllowed','translate',...
                'Deletable',false,'DrawingArea',[line_left.Position(1,1)+eps_x,ylims(1),xlims(2)-(line_left.Position(1,1)+eps_x),ylims(2)-ylims(1)]);
            
            %callbacks
            listener_line_left = addlistener(line_left,'ROIMoved',@(src,evnt) line_left_callback(src,evnt));
            listener_line_right = addlistener(line_right,'ROIMoved',@(src,evnt) line_right_callback(src,evnt));
            this.h_controller.main_axes.UserData = @update_graphics;
%             listener_xlim = addlistener(this.h_controller.main_axes,'XLim','PostSet',@(src,evnt) xlim_callback(src,evnt));
%             listener_ylim = addlistener(this.h_controller.main_axes,'YLim','PostSet',@(src,evnt) ylim_callback(src,evnt));

            function line_left_callback(src,evnt)
                this.limits(1) = line_left.Position(1,1);
                line_left.DrawingArea = [xlims(1),ylims(1),line_right.Position(1,1)-xlims(1)-eps_x,ylims(2)-ylims(1)];
                line_right.DrawingArea = [line_left.Position(1,1)+eps_x,ylims(1),xlims(2)-(line_left.Position(1,1)+eps_x),ylims(2)-ylims(1)];
            end
            
            function line_right_callback(src,evnt)
                this.limits(2) = line_right.Position(1,1);
                line_left.DrawingArea = [xlims(1),ylims(1),line_right.Position(1,1)-xlims(1)-eps_x,ylims(2)-ylims(1)];
                line_right.DrawingArea = [line_left.Position(1,1)+eps_x,ylims(1),xlims(2)-(line_left.Position(1,1)+eps_x),ylims(2)-ylims(1)];
            end
            
            function update_graphics()
                xlims = this.h_controller.main_axes.XLim;
                ylims = this.h_controller.main_axes.YLim;
                line_left.Position = [this.limits(1) ylims(1); this.limits(1) ylims(2)];
                line_right.Position = [this.limits(2) ylims(1); this.limits(2) ylims(2)];
            end
        end   
        
        %init control "Histogram"
        function init_control_Histogram(this)
            
            %clean graphics
            delete(this.h.panel_controller.Children);
            
            %load graphics
            [~,this.h_controller] = guide2fig('controller_Histogram.fig',this.h.panel_controller);
            
            %make sure compact toolbar is visible
            this.h_controller.main_axes.Toolbar.Visible = 'on';
            
            %plot histogram
            h_hist = histogram(this.h_controller.main_axes,this.data);
            grid on;
            xlims = this.h_controller.main_axes.XLim;
            ylims = this.h_controller.main_axes.YLim;
            eps_x = (xlims(2)-xlims(1)) / 1e5; %minimal delta in x axis
            
            %wire buttons
            this.h_controller.button_morebins.Callback = @(src,evnt) morebins_button_callback(h_hist);
            this.h_controller.button_lessbins.Callback = @(src,evnt) lessbins_button_callback(h_hist);
            
            %set limits
            line_left = drawline(this.h_controller.main_axes,'Position',[this.limits(1) ylims(1); this.limits(1) ylims(2)],'Color','red','InteractionsAllowed','translate',...
                'Deletable',false,'DrawingArea',[xlims(1),ylims(1),this.limits(2)-xlims(1)-eps_x,ylims(2)-ylims(1)]);
            line_right = drawline(this.h_controller.main_axes,'Position',[this.limits(2) ylims(1); this.limits(2) ylims(2)],'Color','red','InteractionsAllowed','translate',...
                'Deletable',false,'DrawingArea',[line_left.Position(1,1)+eps_x,ylims(1),xlims(2)-(line_left.Position(1,1)+eps_x),ylims(2)-ylims(1)]);
            
            %callbacks
            listener_line_left = addlistener(line_left,'ROIMoved',@(src,evnt) line_left_callback(src,evnt));
            listener_line_right = addlistener(line_right,'ROIMoved',@(src,evnt) line_right_callback(src,evnt));
            this.h_controller.main_axes.UserData = @update_graphics;
%             listener_xlim = addlistener(this.h_controller.main_axes,'XLim','PostSet',@(src,evnt) xlim_callback(src,evnt));
%             listener_ylim = addlistener(this.h_controller.main_axes,'YLim','PostSet',@(src,evnt) ylim_callback(src,evnt));
            
            function line_left_callback(src,evnt)
                this.limits(1) = line_left.Position(1,1);
                line_left.DrawingArea = [xlims(1),ylims(1),line_right.Position(1,1)-xlims(1)-eps_x,ylims(2)-ylims(1)];
                line_right.DrawingArea = [line_left.Position(1,1)+eps_x,ylims(1),xlims(2)-(line_left.Position(1,1)+eps_x),ylims(2)-ylims(1)];
            end
            
            function line_right_callback(src,evnt)
                this.limits(2) = line_right.Position(1,1);
                line_left.DrawingArea = [xlims(1),ylims(1),line_right.Position(1,1)-xlims(1)-eps_x,ylims(2)-ylims(1)];
                line_right.DrawingArea = [line_left.Position(1,1)+eps_x,ylims(1),xlims(2)-(line_left.Position(1,1)+eps_x),ylims(2)-ylims(1)];
            end
            
            function morebins_button_callback(h_hist)
                morebins(h_hist);
                xlims = this.h_controller.main_axes.XLim;
                ylims = this.h_controller.main_axes.YLim;
                line_left.Position = [this.limits(1) ylims(1); this.limits(1) ylims(2)];
                line_right.Position = [this.limits(2) ylims(1); this.limits(2) ylims(2)];
                line_left.DrawingArea = [xlims(1),ylims(1),line_right.Position(1,1)-xlims(1)-eps_x,ylims(2)-ylims(1)];
                line_right.DrawingArea = [line_left.Position(1,1)+eps_x,ylims(1),xlims(2)-(line_left.Position(1,1)+eps_x),ylims(2)-ylims(1)];
            end
            
            function lessbins_button_callback(h_hist)
                fewerbins(h_hist);
                xlims = this.h_controller.main_axes.XLim;
                ylims = this.h_controller.main_axes.YLim;
                line_left.Position = [this.limits(1) ylims(1); this.limits(1) ylims(2)];
                line_right.Position = [this.limits(2) ylims(1); this.limits(2) ylims(2)];
                line_left.DrawingArea = [xlims(1),ylims(1),line_right.Position(1,1)-xlims(1)-eps_x,ylims(2)-ylims(1)];
                line_right.DrawingArea = [line_left.Position(1,1)+eps_x,ylims(1),xlims(2)-(line_left.Position(1,1)+eps_x),ylims(2)-ylims(1)];
            end
            
            function update_graphics()
                xlims = this.h_controller.main_axes.XLim;
                ylims = this.h_controller.main_axes.YLim;
                line_left.Position = [this.limits(1) ylims(1); this.limits(1) ylims(2)];
                line_right.Position = [this.limits(2) ylims(1); this.limits(2) ylims(2)];
            end
            
%             function xlim_callback(src,evnt)
%                 xlims = this.h_controller.main_axes.XLim;
%                 ylims = this.h_controller.main_axes.YLim;
%                 line_left.Position = [this.limits(1) ylims(1); this.limits(1) ylims(2)];
%                 line_right.Position = [this.limits(2) ylims(1); this.limits(2) ylims(2)];
%             end
%             
%             function ylim_callback(src,evnt)
%                 xlims = this.h_controller.main_axes.XLim;
%                 ylims = this.h_controller.main_axes.YLim;
%                 line_left.Position = [this.limits(1) ylims(1); this.limits(1) ylims(2)];
%                 line_right.Position = [this.limits(2) ylims(1); this.limits(2) ylims(2)];
%             end
        end
    end
end

