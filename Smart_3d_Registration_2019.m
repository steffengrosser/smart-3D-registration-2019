
[ Stack, Meta ] = OME_ReadTiffStack('NT_nucs_decently_stiched.tiff');
Stack = Stack{1};
Stack = reshape( Stack, [Meta.SizeY, Meta.SizeX, Meta.SizeZ, Meta.SizeT] );

%%

% Schwarzpunkt setzen (substract Background)
FirstVolume = Stack( :,:,:,1 );
Black		= median( FirstVolume(:) );
Stack		= Stack - Black;

% Zunächst center of mass stabilisieren
%disp('pre-register center-of-mass...');
%Stack		= RegisterVolumesCOM( Stack );
% -> bringt nix bei den Friedl Daten

% wenn Hintergund auf 0 und stabilisiert: -> ein guter Moment zum Croppen
%disp('crop...');
%Stack		= CropKnoedel4D( Stack );
% -> bringt auch nix

%RUNTERSKALIEREN in x-y Richtung
disp('scale down...');
DownScaling = 0.5;
%    DownScaling = 1;
for t=1:size(Stack,4)
    DownScaled(:,:,:,t) = imresize3( squeeze(Stack(:,:,:,t)), [size(Stack,1)*DownScaling, size(Stack,2)*DownScaling, size(Stack,3)] );
    %waitbar( t/size(Stack,4) );
end
Meta.SizeX	= ceil(Meta.SizeX*DownScaling);
Meta.SizeY	= ceil(Meta.SizeY*DownScaling);
Meta.ScaleY = Meta.ScaleY/DownScaling;
Meta.ScaleX = Meta.ScaleX/DownScaling;
Stack = DownScaled; 

% jetzt ist ca. ~< 50% des Volumes von Knödel besetzt
% -> guter Moment um einen guten Weißwert zu finden und ->8bit Konvertierung
% setze WHITE individuell pro Frame (Helligkeit schwankt)
disp('adjusting brightness...');
for t=1:size(Stack,4)
	Volume	= squeeze( Stack(:,:,:,t) );
	White	= mean(double(Volume(:))) + 4*std(double(Volume(:)))
	Stack8bit(:,:,:,t)	= uint8( double(Stack(:,:,:,t))/White*255 );
end
Stack = Stack8bit;
clear Stack8bit,

%%% FERTIG!
% jetzt haben wir 1 schönen Stack -> saven

% erstmal metadaten setzen
% PIXEL ORDER -> diese Funktion klappt nicht??
% ODER Fiji verreisst es? -> zumindest ist es in Fiji IMMER XYCZT !??
%DimensionOrder = ome.xml.model.enums.DimensionOrder(java.lang.String('XYZT'));
%metadata.setPixelsDimensionOrder(ome.xml.model.enums.DimensionOrder.XYZTC, 0);
% FIJI assumes oder XYZCT -> so lets make it like that

%%

disp('saving...');
clear Stack5D;
Stack5D(:,:,:,1,:) = Stack; % f�ge singleton channel dimension ein: XYZCT

metadata = createMinimalOMEXMLMetadata(Stack5D);
metadata.getPixelsDimensionOrder(0);
metadata.setPixelsDimensionOrder( ome.xml.model.enums.DimensionOrder.XYCZT, 0  );
% ja das ist anders als drei Zeilen vorher behauptet wurde
% aber für FIJI geht es (nur) so

pixelSize = ome.units.quantity.Length(java.lang.Double(Meta.ScaleX), ome.units.UNITS.MICROMETER);
metadata.setPixelsPhysicalSizeX(pixelSize, 0);
metadata.setPixelsPhysicalSizeY(pixelSize, 0);
pixelSizeZ = ome.units.quantity.Length(java.lang.Double(Meta.ScaleZ), ome.units.UNITS.MICROMETER);
metadata.setPixelsPhysicalSizeZ(pixelSizeZ, 0);
for t=1:Meta.SizeT
	timestamp = ome.units.quantity.Time(java.lang.Double(Meta.Timestamp(t)), ome.units.UNITS.SECOND);
	metadata.setPlaneDeltaT(timestamp, 0, t-1);
end
%toInt = @(x) ome.xml.model.primitives.PositiveInteger(java.lang.Integer(x));
%metadata.setPixelsSizeX( toInt(size(Stack5D,2)), 0);
%metadata.setPixelsSizeY( toInt(size(Stack5D,1)), 0);
%metadata.setPixelsSizeZ( toInt(size(Stack5D,4)), 0);

OutFile = 'NT_nucs_preprocessed.tiff';
delete( OutFile ); % delete, because else bfsave will just APPEND data

bfsave( Stack, OutFile, 'Compression', 'LZW', 'metadata', metadata );

disp( 'saved to:' );
disp( OutFile );
disp( ' ' );

%%

[Stack, Meta]	= Tracking_LoadStack('NT_nucs_preprocessed.tiff'); 
Meta.ScaleZ = 5; % correct by hand, gets lost somewhere

ShowStack(Stack);
RegStack		= StackRegistration2018_5(Stack(:,:,3:end,1:3), Meta);
ShowStack(RegStack);


Stack			= RegStack; % läuft gut -> speichern
save( 'NT_nucs_Reg.mat', 'Meta', 'Stack' );



