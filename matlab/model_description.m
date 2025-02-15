function [ mapObj, d_dist, d_angle ] = model_description( model_points, model_normals )
%model_description 
%   Detailed explanation goes here

min_coords = min(model_points);
max_coords = max(model_points);
center = mean([min_coords; max_coords]);

dists = sqrt(sum(model_points-repmat(center, size(model_points,1), 1).^2, 2));
max_dist = max(dists);

d_dist = 0.1 * max_dist;
n_angle = 30;
d_angle = 2*pi / n_angle;

indices = 1:size(model_points,1);
[p,q] = meshgrid(indices, indices);
index_pairs = [p(:) q(:)];

mapObj = containers.Map('KeyType', 'double', 'ValueType', 'any');
Opt.Format = 'hex';
Opt.Method = 'SHA-1';

for ii = 1:size(index_pairs,1)
  
  if mod(ii, 1000) == 0
    fprintf('On point %d of %d\n', ii, size(index_pairs,1));
  end
  
  % Handle case of identical point in pair
  if index_pairs(ii,1) == index_pairs(ii,2)
    continue
  end
  
  F = real(point_pair_feature(model_points(index_pairs(ii,1),:), ...
                         model_normals(index_pairs(ii,1),:), ...
                         model_points(index_pairs(ii,2),:), ...
                         model_normals(index_pairs(ii,2),:)));
                       
%   F_disc = [F(1)-mod(F(1),d_dist); F(2:4)-mod(F(2:4),d_angle)];
  F_disc = [quant(F(1),d_dist); quant(F(2:4),d_angle)];
  
  hash = DataHash(F_disc, Opt);
  key = hex2num(hash(1:16));
  
  if isnan(key)
    continue
  end
  
  if isKey(mapObj, key)
    entry = mapObj(key);
    mapObj(key) = [entry; index_pairs(ii,1), index_pairs(ii,2)];
  else
    mapObj(key) = [index_pairs(ii,1), index_pairs(ii,2)];
  end
  
end

end
