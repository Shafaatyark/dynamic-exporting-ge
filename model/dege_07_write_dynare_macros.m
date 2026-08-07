function macros_path = dege_07_write_dynare_macros(output_dir,num_c,J,dynamic,free_entry,target)
%DEGE_07_WRITE_DYNARE_MACROS Write the runtime Dynare macro configuration.
% The file belongs in an isolated job directory and is never committed.

countries_array = fliplr(1:num_c);
countries_array_str = regexprep( mat2str(countries_array), {'\[', '\]', '\s+'}, {'', '', ','});

J_str = regexprep( mat2str(J'), {'\[', '\]', '\s+'}, {'', '', ','});

% tau = log(tau);
if nargin < 1 || isempty(output_dir)
    error('dege:macros:MissingOutputDirectory', ...
        'An isolated Dynare output directory is required.');
end
if ~isfolder(output_dir)
    mkdir(output_dir);
end
macros_path = fullfile(output_dir,'dege_macros.txt');
fid = fopen(macros_path,'wt');
if fid == -1
    error('dege:macros:FileOpenFailed', ...
        'Could not open macro file for writing: %s', macros_path);
end
fprintf(fid, strcat('@#define countries=[',countries_array_str,'] \n'));
fprintf(fid, strcat('@#define Js=[',J_str,'] \n'));
% for i=1:num_c
%     fprintf(fid, strcat('@#define tau',num2str(i),'=['));
%     for j=1:num_c
%         if j<num_c
%             fprintf(fid, strcat('"',num2str(tau(i,j)),'"',','));
%         else
%             fprintf(fid, strcat('"',num2str(tau(i,j)),'"'));
%         end
%     end
%     fprintf(fid, '] \n');
% end
fprintf(fid,strcat('@#define dynamic_mod = ',num2str(dynamic),' \n'));
fprintf(fid,strcat('@#define free_entry = ',num2str(free_entry),' \n'));
fprintf(fid,strcat('@#define pref = ',num2str(target.pref),' \n'));

fclose(fid);



end
