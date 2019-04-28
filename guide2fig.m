function [target,h] = guide2fig(guide_fig,target,varargin)
% This function gets a figure from guide, and transform it into a normal figure.
% The output is the new figure handle, and the handles of the objects inside the figure

if nargin<2
    target = figure;
elseif ischar(target)
    varargin = [target,varargin];
    target = figure(varargin{:});
end

switch class(guide_fig)
    case 'matlab.ui.Figure'
        % OK
    case 'char'
        guide_fig = openfig(guide_fig,'invisible');
    otherwise
        error('Invalid input type')
end

h = guihandles(guide_fig);

for i=length(guide_fig.Children):-1:1
    guide_fig.Children(i).Parent = target;
end
close(guide_fig);


end

