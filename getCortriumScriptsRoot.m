function cortrium_matlab_scripts_root_path = getCortriumScriptsRoot()
    % Root path to Cortrium Matlab scripts
    full_path_to_this_script = mfilename('fullpath');
    [cortrium_matlab_scripts_root_path,~,~] = fileparts(full_path_to_this_script);
end