function entity = mrio_entity_prep(climada_mriot, params) % uncomment to run as function
% mrio entity prep
% MODULE:
%   advanced
% NAME:
%   mrio_entity_prep
% PURPOSE:
%   load centroids and prepare entities for mrio (multi regional I/O table project)
%
%   NOTE: see PARAMETERS in code
%
%   previous call: 
%   see isimip_gdp_entity to generate the global centroids and entity
%   climada_mriot = mrio_read_table;
%   next call: 
%   direct_mainsector_risk = mrio_direct_risk_calc(entity, hazard, climada_mriot, risk_measure); % just to illustrate
% CALLING SEQUENCE:
%   entity = mrio_entity_prep(climada_mriot, params);
% EXAMPLE:
%   climada_mriot = mrio_read_table;
%   params.plot_centroids = 1; params.plot_entity = 1;
%   entity = mrio_entity_prep(climada_mriot, params);
% INPUTS:
%   climada_mriot: a struct with ten fields, one of them being countries_iso.
%       The latter is important for this function. The struct represents a general climada
%       mriot structure whose basic properties are the same regardless of the
%       provided mriot it is based on, see mrio_read_table; 
% OPTIONAL INPUT PARAMETERS:
%   params: a structure with the fields
%       plot_centroids: =1 to plot the centroids, =0 not (default)
%       plot_entity: =1 to plot the entity, =0 not (default)
% OUTPUTS:
%   entity: the global entity
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20171206, initial
% Ediz Herms, ediz.herms@outlook.com, 20171207, normalize assets per country
% Ediz Herms, ediz.herms@outlook.com, 20180112, ...mrio table as input
%-

entity = []; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
% and to set default value where  appropriate
if ~exist('params', 'var'), params = struct; end % in case we want to pass all parameters as structure
if ~exist('climada_mriot', 'var'), climada_mriot = []; end 

% locate the module's data folder (here  one folder
% below of the current folder, i.e. in the same level as code folder)
% module_data_dir=[climada_global.modules_dir filesep 'climada_advanced' filesep 'data']; 

% PARAMETERS
centroids_file = 'GLB_NatID_grid_0360as_adv_1'; % the global centroids
entity_file = 'GLB_0360as_ismip_2018'; % the global entity

if isempty(climada_mriot), 
    fprintf('loading centroids %s\n',centroids_file); climada_mriot = mrio_read_table; 
end
if isstruct(params)
    if ~isfield(params,'plot_centroids'), params.plot_centroids = []; end
    if ~isfield(params,'plot_entity'), params.plot_entity = []; end
end

% load global centroids
fprintf('loading centroids %s\n',centroids_file);
centroids = climada_centroids_load(centroids_file);

if params.plot_centroids % plot the centroids
    figure('Name', 'centroids');
    country_pos = (centroids.centroid_ID < 3e6); % find high(er) resolution centroids within countries
    plot(centroids.lon(country_pos), centroids.lat(country_pos), '.g'); hold on;
    grid_pos = (centroids.centroid_ID >= 3e6); % find coarse resolution centroids for regular grid
    plot(centroids.lon(grid_pos), centroids.lat(grid_pos), '.r', 'MarkerSize', .1)
    climada_plot_world_borders
    legend({'country centroids [10km]','grid centroids [100km]'})
    title('GLB NatID grid 0360as adv 1')
end % params.plot_centroids

% load global entity
fprintf('loading entity %s\n',entity_file);
entity = climada_entity_load(entity_file);

countries_ISO3 = entity.assets.NatID_RegID.ISO3;
mrio_countries_ISO3 = unique(climada_mriot.countries_iso, 'stable');
n_mrio_countries = climada_mriot.no_of_countries;

% normalization of asset values for all countries as specified in mrio table
for mrio_country_i = 1:n_mrio_countries
    country_ISO3 = mrio_countries_ISO3(mrio_country_i); % extract ISO code
    if country_ISO3 ~= 'ROW'
        country_NatID = find(ismember(countries_ISO3, country_ISO3)); % extract NatID
        sel_pos = intersect(find(ismember(entity.assets.NatID, country_NatID)), find(~isnan(entity.assets.Value))); % select all non-NaN assets % select all non-NaN assets of this country
    else % 'Rest of World' (RoW) is viewed as a country 
        list_RoW_ISO3 = setdiff(countries_ISO3, mrio_countries_ISO3); % find all countries that are not individually listed in the MRIO table 
        list_RoW_NatID = find(ismember(countries_ISO3, list_RoW_ISO3)); % extract NatID
        sel_pos = intersect(find(ismember(entity.assets.NatID, list_RoW_NatID)), find(~isnan(entity.assets.Value))); % select all non-NaN RoW assets
    end
    entity.assets.Value(sel_pos) = entity.assets.Value(sel_pos)/sum(entity.assets.Value(sel_pos)); % normalize assets
end % mrio_country_i

if params.plot_entity % plot the centroids
    figure('Name', 'entity');
    climada_entity_plot(entity);
end % params.plot_entity

end % mrio_entity_prep
