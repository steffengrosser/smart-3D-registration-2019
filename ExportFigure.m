function ExportFigure( hf, FileName, SizeCm, ShowPDF )

	if ~exist('SizeCm','var')
		PaperSize = [16 12];
	else
		if ~isempty(SizeCm)
			PaperSize = SizeCm; % paper
		end
	end
		
	if ~exist('ShowPDF', 'var')
		ShowPDF = true;
	end
	
	if ~isempty(SizeCm)
		set(hf, 'PaperPosition', [0 0 PaperSize]);
		set(hf, 'PaperSize', PaperSize);
	end
	
	% correct filenames: if there is a dot in it, there will be problems
	% with the file suffix! so remove dots instead
	FileName = strrep( FileName, '.', '_' );
	

	% export as .fig and as .bla
	%saveas( hf, [FileName '.fig']);
	print( '-r300', '-painters', hf, FileName, '-dpdf');
%	print( '-painters', hf, FileName, '-deps');
%	print( '-opengl', hf, FileName, '-dpdf');	
	print( '-r300', hf, FileName, '-dpng');
	
	
	if ShowPDF == true
		if isunix
			unix(['evince "' FileName '.pdf"'], '-echo');
		elseif ispc
			% put a windos command here
% 			% "C:\Program Files\Tracker Software\PDF Viewer\PDFXCview.exe"
% 			command = ['"C:\Program Files\Tracker Software\PDF Viewer\PDFXCview.exe"' ...
% 				' "' FileName '.pdf"'];
% 			dos( command );
			open( [FileName '.pdf'] );
        end       
	end
end
