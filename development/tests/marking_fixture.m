function [file,cleanup]=marking_fixture()
% Deterministic plate for testing annotation mechanics, not biological accuracy.
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
file=fullfile(folder,'marking plate.png'); [x,y]=meshgrid(1:600);
plate=(x-300).^2+(y-300).^2<260^2;
I=repmat(single(0.1),600,600,3); bg=[0.62 0.37 0.34];
for c=1:3, v=I(:,:,c); v(plate)=bg(c); I(:,:,c)=v; end
[cx,cy]=meshgrid(180:50:430); centers=[cx(:),cy(:)];
for k=1:size(centers,1)
    radius=4; color=[0.90 0.49 0.53];
    if mod(k,5)==0, radius=10; color=[0.96 0.25 0.47]; end
    mask=(x-centers(k,1)).^2+(y-centers(k,2)).^2<=radius^2;
    for c=1:3, v=I(:,:,c); v(mask)=color(c); I(:,:,c)=v; end
end
imwrite(I,file);
end
