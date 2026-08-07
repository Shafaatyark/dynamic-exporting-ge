function dynare_path = dege_configure_dynare()
%DEGE_CONFIGURE_DYNARE Configure Dynare without machine-specific paths.
%
% Set DEGE_DYNARE_PATH to Dynare's MATLAB/Octave directory, or place the
% Dynare command on the MATLAB/Octave path before calling the simulator.

dynare_path = getenv('DEGE_DYNARE_PATH');
if isempty(dynare_path)
    dynare_path = getenv('DYNARE_MATLAB_PATH');
end

if ~isempty(dynare_path)
    dynare_path = strtrim(dynare_path);
    matlab_subdir = fullfile(dynare_path, 'matlab');
    if exist(matlab_subdir, 'dir') == 7
        dynare_path = matlab_subdir;
    end
    if exist(dynare_path, 'dir') ~= 7
        error('dege:dynare:InvalidPath', ...
            'Configured Dynare path does not exist: %s', dynare_path);
    end
    addpath(dynare_path);
end

if exist('dynare', 'file') ~= 2
    error('dege:dynare:NotFound', ...
        ['Dynare is not available. Set DEGE_DYNARE_PATH to its MATLAB/' ...
         'Octave directory or add Dynare to the interpreter path.']);
end

resolved = which('dynare');
if ~isempty(resolved)
    dynare_path = fileparts(resolved);
end

version_string = dynare_version();
tokens = regexp(version_string, '^(\d+)\.(\d+)', 'tokens', 'once');
if isempty(tokens)
    error('dege:dynare:UnknownVersion', ...
        'Could not verify the installed Dynare version: %s', version_string);
end
major_version = str2double(tokens{1});
minor_version = str2double(tokens{2});
if major_version < 7 || (major_version == 7 && minor_version < 1)
    error('dege:dynare:UnsupportedVersion', ...
        'Dynare 7.1 or newer is required; found Dynare %s.', version_string);
end

end
