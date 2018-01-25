function [direct_subsector_risk, direct_country_risk] = mrio_direct_risk_calc(entity, hazard, climada_mriot, aggregated_mriot, risk_measure) % uncomment to run as function
% mrio direct risk ralc
% MODULE:
%   advanced
% NAME:
%   mrio_direct_risk_calc
% PURPOSE:
%   Caculate direct risk per subsector and country given an encoded entity (assets and damage functions), 
%   a hazard event set, a risk measure and a general climada MRIO table (as well as an aggregated climada mriot struct).
%
%   NOTE: see PARAMETERS in code
%
%   previous call: 
%
%   next call:  % just to illustrate
%   [subsector_risk, country_risk, leontief_inverse, climada_nan_mriot] = mrio_leontief_calc(direct_subsector_risk, climada_mriot)
% CALLING SEQUENCE:
%   [direct_subsector_risk, direct_country_risk] = mrio_direct_risk_calc(entity, hazard, climada_mriot, aggregated_mriot);
% EXAMPLE:
%   climada_mriot = mrio_read_table;
%   aggregated_mriot = mrio_aggregate_table(climada_mriot);
%   entity = mrio_entity_prep(climada_mriot);
%   hazard = climada_hazard_load;
%   [direct_subsector_risk, direct_country_risk] = mrio_direct_risk_calc(entity, hazard, climada_mriot, aggregated_mriot);
% INPUTS:
%   entity: a struct, see climada_entity_read for details
%   hazard: a struct, see e.g. climada_tc_hazard_set
%   climada_mriot: a structure with ten fields. It represents a general climada
%       mriot structure whose basic properties are the same regardless of the
%       provided mriot it is based on, see mrio_read_table;
%   aggregated_mriot: an aggregated climada mriot struct as
%       produced by mrio_aggregate_table.
% OPTIONAL INPUT PARAMETERS:
%   risk_measure: risk measure to be applied (string), default is the Expected Annual Damage (EAD)
% OUTPUTS:
%   direct_subsector_risk: a table containing as one variable the direct risk for each
%       subsector/country combination covered in the original mriot. The
%       order of entries follows the same as in the entire process, i.e.
%       entry mapping is still possible via the climada_mriot.setors and
%       climada_mriot.countries arrays. The table further contins three
%       more variables with the country names, country ISO codes and sector names
%       corresponging to the direct risk values.
%  direct_country_risk: a table containing as one variable the direct risk per country (aggregated across all subsectors) 
%       based on the risk measure chosen. Further a variable with correpsonding country
%       names and country ISO codes, respectively.
% MODIFICATION HISTORY:
% Ediz Herms, ediz.herms@outlook.com, 20180115, initial
% Ediz Herms, ediz.herms@outlook.com, 20180118, disaggregate direct risk to all subsectors for each country
%-

direct_subsector_risk = []; % init output
direct_country_risk = []; % init output
direct_mainsector_risk = []; % init

global climada_global
if ~climada_init_vars, return; end % init/import global variables

% poor man's version to check arguments
if ~exist('entity', 'var'), entity = []; end 
if ~exist('hazard', 'var'), hazard = []; end 
if ~exist('climada_mriot', 'var'), climada_mriot = []; end
if ~exist('aggregated_mriot', 'var'), aggregated_mriot = []; end
if ~exist('risk_measure', 'var'), risk_measure = []; end

% locate the module's data folder (here  one folder
% below of the current folder, i.e. in the same level as code folder)
if exist([climada_global.modules_dir filesep 'advanced' filesep 'data'],'dir') 
    module_data_dir=[climada_global.modules_dir filesep 'advanced' filesep 'data'];
else
    module_data_dir=[climada_global.modules_dir filesep 'climada_advanced' filesep 'data'];
end

% PARAMETERS
if isempty(entity), entity = mrio_entity_prep; end
if isempty(hazard), hazard = climada_hazard_load; end
if isempty(climada_mriot), climada_mriot = mrio_read_table; end
if isempty(aggregated_mriot), aggregated_mriot = mrio_aggregate_table(climada_mriot); end
if isempty(risk_measure), risk_measure = 'EAD'; end

countries_ISO3 = entity.assets.NatID_RegID.ISO3; % TO DO: entity l�sung finden 
mrio_countries_ISO3 = unique(climada_mriot.countries_iso, 'stable');

n_mainsectors = length(categories(climada_mriot.climada_sect_name));
n_mrio_countries = length(mrio_countries_ISO3);

% direct risk calculation per mainsector and per country
direct_mainsector_risk = zeros(n_mainsectors*n_mrio_countries);
for mainsector_j = 1:n_mainsectors
    
    % load centroids and prepare entities for mrio risk estimation 
    % entity = mrio_entity_prep(climada_mriot); % at the moment we are not differentiating between sectors (!!!)

    % calculation for all countries as specified in mrio table
    for mrio_country_i = 1:n_mrio_countries

        country_ISO3 = mrio_countries_ISO3(mrio_country_i); % extract ISO code

        if country_ISO3 ~= 'ROW' 
            country_NatID = find(ismember(countries_ISO3, country_ISO3)); % extract NatID
            sel_assets = eq(ismember(entity.assets.NatID, country_NatID),~isnan(entity.assets.Value)); % select all non-NaN assets of this country
        else % 'Rest of World' (ROW) is viewed as a country 
            list_RoW_ISO3 = setdiff(countries_ISO3, mrio_countries_ISO3); % find all countries that are not individually listed in the MRIO table 
            list_RoW_NatID = find(ismember(countries_ISO3, list_RoW_ISO3)); % extract NatID
            sel_assets = eq(ismember(entity.assets.NatID, list_RoW_NatID),~isnan(entity.assets.Value)); % select all non-NaN RoW assets
        end

        entity_sel = entity;
        entity_sel.assets.Value = entity.assets.Value .* sel_assets;  % set values = 0 for all assets outside country i.

        % calculate event damage set
        EDS = climada_EDS_calc(entity_sel,hazard,'' ,'' ,2 ,'');

        % Calculate Damage exceedence Frequency Curve (DFC)
        % DFC = climada_EDS2DFC(EDS);

        % convert an event (per occurrence) damage set (EDS) into a year damage set (YDS)
        YDS = climada_EDS2YDS(EDS, hazard);

        % quantify risk with specified risk measure 
        switch risk_measure
            case 'EAD' % Expected Annual Damage
                direct_mainsector_risk(mainsector_j+n_mainsectors*(mrio_country_i-1)) = YDS.ED;
            case '100y-event' % TO DO 
                return_period = 100;
                sel_pos = max(find(DFC.return_period >= return_period));
                direct_mainsector_risk(mainsector_j+n_mainsectors*(mrio_country_i-1)) = DFC.damage(sel_pos);
            case '50y-event' % TO DO 
                return_period = 50;
                sel_pos = max(find(DFC.return_period >= return_period));
                direct_mainsector_risk(mainsector_j+n_mainsectors*(mrio_country_i-1)) = DFC.damage(sel_pos);
            case '20y-event' % TO DO 
                return_period = 20;
                sel_pos = max(find(DFC.return_period >= return_period));
                direct_mainsector_risk(mainsector_j+n_mainsectors*(mrio_country_i-1)) = DFC.damage(sel_pos);
            case '10y-event' % TO DO 
                return_period = 10;
                sel_pos = max(find(DFC.return_period >= return_period));
                direct_mainsector_risk(mainsector_j+n_mainsectors*(mrio_country_i-1)) = DFC.damage(sel_pos);
            case 'worst-case' % TO DO 
                sel_pos = max(find(DFC.return_period));
                direct_mainsector_risk(mainsector_j+n_mainsectors*(mrio_country_i-1)) = DFC.damage(sel_pos);
            otherwise
                % TO DO
        end % switch risk_measure
        
    end % mrio_country_i
    
end % mainsector_j

% disaggregate direct risk to all subsectors for each country
[direct_subsector_risk, direct_country_risk] = mrio_disaggregate_risk(direct_mainsector_risk, climada_mriot, aggregated_mriot);

end % mrio_direct_risk_calc