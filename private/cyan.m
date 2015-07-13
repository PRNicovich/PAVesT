function C = cyan(m)
%CYAN  Cyan Colormap
%   CYAN(M) is an M-by-3 matrix colormap for increasing red intensity.
%   CYAN, by itself, is the same length as the current figure's
%   colormap. If no figure exists, MATLAB creates one.
%
%   See also GREEN, RED, JET, HSV, HOT, PINK, FLAG, COLORMAP, RGBPLOT.


if nargin < 1
   m = size(get(gcf,'colormap'),1);
end

C = zeros(m,3);
C(:,2:3) = repmat((0:(1/(m-1)):1), 2, 1)';