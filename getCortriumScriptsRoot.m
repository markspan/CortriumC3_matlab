function cortrium_matlab_scripts_root_path = getCortriumScriptsRoot()
    if isdeployed
        % For compiled, standalone .exe versions of scripts, this will
        % return path to the .exe (when called before navigating to other
        % directories)
        cortrium_matlab_scripts_root_path = pwd;
    else
        % For scripts executed in Matlab environment, this will
        % return path to this script, which should be placed at the root level of Cortrium Matlab scripts.
        full_path_to_this_script = mfilename('fullpath');
        [cortrium_matlab_scripts_root_path,~,~] = fileparts(full_path_to_this_script);
    end
end