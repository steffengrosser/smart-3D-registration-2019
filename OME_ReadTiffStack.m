function [ Stack, MetaData ] = OME_ReadTiffStack( FileName )

	if ~exist('FileName', 'var')
		[FileName,Path] = uigetfile('*');
		FileName		= fullfile( Path, FileName )
	end
	
	data = bfopen( FileName );
	MetaData = GetOMEData( FileName );
	
	
	
	% some stacks (e.g. Spidi) have 3 (identical) channels
	% but its not even indicated,e.g. we've got 3 times as many timelapse
	% frames as we need -- find and exclude those cases:
	if all(all(data{1}{1,1}==data{1}{2,1})) && ...
			all(all(data{1}{1,1}==data{1}{3,1})) && ...
			~all(all(data{1}{1,1}==data{1}{4,1}))
		% so the first 3 frames are the same
		% assume we have 3 "channels"
		Stack		= cat( 3, data{1}{1:3:end,1} );	
	else
		% no channel doubling, just cat all the frames together:
		% ...
		
		% make a Stack which is for Leica LSM:
		for c=1:MetaData.SizeC
			Stack{c} = cat( 3, data{1}{c:MetaData.SizeC:end,1} );
		end
		
	end

end

