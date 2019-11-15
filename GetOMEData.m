%this is a modified version of an original script by Sebastian Rhode (2015)

function OMEData = GetOMEData(filename)

reader = bfGetReader(filename);

% You can then access the OME metadata using the getMetadataStore() method:
omeMeta = reader.getMetadataStore();

% get the actual metadata and store them in a structured array

% Get dimension order
OMEData.DimOrder = char(omeMeta.getPixelsDimensionOrder(0).getValue());

% Number of series inside the complete data set
OMEData.SeriesCount = reader.getSeriesCount();

% Dimension Sizes C - T - Z - X - Y
OMEData.SizeC	= omeMeta.getPixelsSizeC(0).getValue();
OMEData.SizeT	= omeMeta.getPixelsSizeT(0).getValue();
OMEData.SizeZ	= omeMeta.getPixelsSizeZ(0).getValue();
OMEData.SizeX	= omeMeta.getPixelsSizeX(0).getValue();
OMEData.SizeY	= omeMeta.getPixelsSizeY(0).getValue();
OMEData.Name	= char(omeMeta.getImageName(0));



 OMEData.ScaleX = double(omeMeta.getPixelsPhysicalSizeX(0).value()); % in micron
 OMEData.ScaleY = double(omeMeta.getPixelsPhysicalSizeY(0).value()); % in micron

try
    OMEData.ScaleZ = double(omeMeta.getPixelsPhysicalSizeZ(0).value()); % in micron
catch
	if OMEData.SizeZ == 0
    % in case of only a single z-plane set to zero
	else % we cannot read the z-scale, but there should be one ...
		
		% this is a WORKAROUND
		
		% if its a .lei file, it might have a negative physical
		% z-dimensions.. seems to destroy things.
		TXTfile = [filename(1:end-3) 'txt'];
		if exist(TXTfile,'file')
			warning('cannot read z-Scale ...try to read from .txt file!');
			bla = importdata( TXTfile, '\t', 33 );
			PhysZ = bla{33}(strfind( bla{33}, ':' )+1:end);
			warning(['try to interpret: ' PhysZ]);
			% should read 'Physical Length: ...'
			PhysZ = sscanf(PhysZ, '%f');
			OMEData.ScaleZ = abs(PhysZ/(OMEData.SizeZ-1)*1e6);
			warning( ['leads to z-Scale of 1px = ' num2str(OMEData.ScaleZ) ' micron']);
		end
	end
end

OMEData.Scale = [OMEData.ScaleX, OMEData.ScaleY, OMEData.ScaleZ];
  

for j=1:OMEData.SizeC
	OMEData.ChannelNames{j} = char(omeMeta.getChannelName(0,j-1));
end

% Get Timestamps
if OMEData.SizeT > 1
    planeCount = omeMeta.getPlaneCount(0);
    counter = 0;
    for j=1:planeCount
      deltaT = double(omeMeta.getPlaneDeltaT(0, j-1).value());
      %if (deltaT == null) break; end
      % convert plane ZCT coordinates into image plane index
      z = omeMeta.getPlaneTheZ(0, j-1).getValue();
      c = omeMeta.getPlaneTheC(0, j-1).getValue();
      t = omeMeta.getPlaneTheT(0, j-1).getValue();
      if (z == 0 && c == 0)
          counter=counter +1;
        OMEData.Timestamp(counter) = deltaT; % in seconds
      end
    end
else
    OMEData.Timestamp = 1:OMEData.SizeT;
end
    
    
% close BioFormats Reader

reader.close()


