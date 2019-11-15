function [ RegisteredStack ] = StackRegistration2018_5( Stack, MetaData )
    %Stack = single(Stack);
    disp( ['REGISTRATION of ' MetaData.FileName] );

	%v5: 1st downscaling to quickly find good starting values for a second,
	%full-res registration!
    %%% v4: first downscales to find registration -> then apply it to the
    %%% full image
	%%%% v3: now with multiple algorhithm registration!

    disp('scale down...');
	tic;
    DownScaling = 0.125;
 	for t=1:size(Stack,4)
 		DownScaled(:,:,:,t) = imresize3( squeeze(Stack(:,:,:,t)), [size(Stack,1)*DownScaling, size(Stack,2)*DownScaling, size(Stack,3)] );
    end
    MetaDown = MetaData;
    MetaDown.SizeX	= ceil(MetaData.SizeX*DownScaling);
    MetaDown.SizeY	= ceil(MetaData.SizeY*DownScaling);
    MetaDown.ScaleY = MetaData.ScaleY/DownScaling;
    MetaDown.ScaleX = MetaData.ScaleX/DownScaling;
    
  
	% now the multi-step registration
	
	% Registration options
	[OptRSGD, MetricMeanSquares]  = imregconfig('monomodal');
 	OptRSGD.GradientMagnitudeTolerance = 0.0005;
 	OptRSGD.MaximumStepLength = 0.2;
	%optimizer.MaximumStepLength = 0.05;
	OptRSGD.MaximumIterations = 1000;

	OptRSGD2 = OptRSGD;
 	OptRSGD2.MaximumStepLength = 0.5;
	OptRSGD2.GradientMagnitudeTolerance = 0.00005;
	
	
	OptOPOE = registration.optimizer.OnePlusOneEvolutionary;
    OptOPOE.GrowthFactor = 1.02;
	OptOPOE.MaximumIterations = 1000;
	MetricMMI	= registration.metric.MattesMutualInformation;

	OptOPOE2 = OptOPOE;
	OptOPOE2.InitialRadius = 2e-3;

	% multiple registration steps with different settings
	RegistrationSteps = { ...
		{OptRSGD, MetricMeanSquares}, ...
		{OptRSGD, MetricMMI}, ...
		{OptRSGD2, MetricMeanSquares}, ...
		{OptRSGD2, MetricMMI}, ...
		{OptOPOE, MetricMeanSquares}, ...
		{OptOPOE, MetricMMI}, ...
		{OptOPOE2, MetricMeanSquares} ...
		{OptOPOE2, MetricMMI} ...
		};
	
	AlgoDescriptions = {'RGSD+MeanSq.', 'RGSD+MMI', 'RGSD2+MeanSq.', 'RGSD2+MMI', ...
		'OPOE+MeanSq.', 'OPOE+MMI', 'OPOE2+MeanSq.', 'OPOE2+MMI' };

	% reserve memory
	RegisteredFullStack = zeros( size(Stack), class(Stack) );
	RegisteredDownScaled = zeros( size(DownScaled), class(DownScaled) );

    disp('registration of downscaled stack ...');
    waitbar(0, 'Registration, run 1/2');
	StandardFigureSettings;
	hf = figure; % for output during reg

	
	
	for t=1:size(Stack, 4)

		if t>1
			clear im3D;
			clear tform;
		end

		This				= squeeze(DownScaled(:,:,:,t));
		% add some empty planes
		AdditionalPlanes	= 5;
		empty_planes		= zeros(size(DownScaled,1),size(DownScaled,2),AdditionalPlanes, class(This));
		This				= cat(3, empty_planes, This, empty_planes);       
		ReferenceObject		= imref3d(size(This), MetaDown.ScaleX, MetaDown.ScaleY, MetaDown.ScaleZ);
		

		% Register
		if t>1
			% find rigid rotations in eq. plane -> quick and helps!
%  			EqPlaneFix			= FixedImage(:,:,round(end/2));
%  			EqPlaneNew			= im3D(:,:,round(end/2));
%  			PreTransformation	= imregcorr(EqPlaneNew, EqPlaneFix, 'rigid');
%  			
%  			Rfixed = imref2d(size(EqPlaneFix));
%  			EqPlanePreTransformed = imwarp(EqPlaneNew,PreTransformation,'OutputView',Rfixed);
%  			imshowpair(EqPlaneFix,EqPlaneNew);
%  			imshowpair(EqPlaneFix,EqPlanePreTransformed);

			corr(t,2) = FrameToFrameCorr( This, OldImage ); % (this is the unregistered stack against the unregistered last frame)
			corr(t,1) = FrameToFrameCorr( This, FixedImage ); % (this is the unregistered stack against the registered last frame)
			
			for r=1:length(RegistrationSteps)
			%[im3D, tform, NewReferenceObject] = imregister2_Kopie(im3D,ReferenceObject,FixedImage,ReferenceObject,'rigid',optimizer,metric, 'InitialTransformation', PreTransformation);
				try
					[Reg{r}, tform{r}, ~] = imregister2_Kopie(This,ReferenceObject,FixedImage,ReferenceObject,'rigid', ...
						RegistrationSteps{r}{1},RegistrationSteps{r}{2}, ... % choose the corresponding optimizer and metric
						'InitialTransformation', TFormDown{t-1} ... % use last frame transformation as a starting guess
						);
				catch
					warning('emergeny ... trying second-last tform as input ...')
					if t>2
						[Reg{r}, tform{r}, ~] = imregister2_Kopie(This,ReferenceObject,FixedImage,ReferenceObject,'rigid', ...
							RegistrationSteps{r}{1},RegistrationSteps{r}{2}, ... % choose the corresponding optimizer and metric
							'InitialTransformation', TFormDown{t-2} ... % use last frame transformation as a starting guess
							);
					else % cant go tback 2 frames because there was no frame then:
						Reg{r} = zeros(size(FixedImage));
					end
				end					
				corr(t,r+2) = FrameToFrameCorr( FixedImage, Reg{r} );
			end
			
			% compare and output
			[BestCorr(t),best(t)] = max(corr(t,:));
			if best(t)>2
				best(t) = best(t) - 2; % weil index 1 ist ja gar nicht registered
			end
			%disp( corr(t,:) );
			%disp( ['best corr is #' num2str(best) ] );
			
			figure(hf);
			subplot 311;
			hold off;
			plot( corr(:,1:2), '--' );
			hold on;
			plot( corr(:,1:end) );
			ylim([exp(-0.5) 1.01]);
			xlim([1 size(Stack, 4)]);
			ylabel('frame correlation $c(t,t+1)$');
			set(gca, 'yscale','log');
			titleleft( [MetaData.FileName(1:end-8), ': algorithm comparison (downscaled stack)'] );
			
			FixedImage		= Reg{best(t)};
			TFormDown{t}	= tform{best(t)};
		else
			% only first frame
			corr(1,1:length(RegistrationSteps)+1) = 1;
			BestCorr(1)		= 1;
			FixedImage		= This;
			TFormDown{1}	= affine3d;
		end
		
		OldImage	= This;
		% format y,x,z,t
		RegisteredDownScaled(:,:,:,t) = FixedImage(:,:,1+AdditionalPlanes:end-AdditionalPlanes);

        waitbar(t/(size(Stack, 4)-1));
	end
    close(waitbar(0));
    toc;
	

	legend( {'unreg vs. unreg', 'unreg vs. reg', AlgoDescriptions{:}}, 'location', 'southwest');

	
	
	
    % registration of downscaleds stack is done. apply the transformations
    % to the FULL STACK
    disp('registration of full size stack ...');
	tic;
	waitbar(0, 'Registrationm run 2/2');
	figure(hf);
	subplot 312;

	
	for t=1:size(Stack, 4)
		if t>1
			clear im3D;
			clear tform;
		end
		This				= squeeze(Stack(:,:,:,t));
		% add some empty planes
		AdditionalPlanes	= 5;
		empty_planes		= zeros(size(This,1), size(This,2), AdditionalPlanes, class(This));
		This				= cat(3, empty_planes, This, empty_planes);       
		ReferenceObject		= imref3d(size(This), MetaData.ScaleX, MetaData.ScaleY, MetaData.ScaleZ);

		% Register
		if t>1
			corrfull(t,2) = FrameToFrameCorr( This, OldImage ); % (this is the unregistered stack against the unregistered last frame)
			corrfull(t,1) = FrameToFrameCorr( This, FixedImage ); % (this is the unregistered stack against the registered last frame)
			
			r = best(t); % choose the best registration algo
			try
				[FullReg, FullTForm, ~] = imregister2_Kopie(This,ReferenceObject,FixedImage,ReferenceObject,'rigid', ...
					RegistrationSteps{r}{1},RegistrationSteps{r}{2}, ...
					'InitialTransformation', TFormDown{t} ... % use downscaled transformation as a starting guess
					);
			catch
				warning('emergeny ... trying second-last tform as input ...')
				[FullReg, FullTForm, ~] = imregister2_Kopie(This,ReferenceObject,FixedImage,ReferenceObject,'rigid', ...
					RegistrationSteps{r}{1},RegistrationSteps{r}{2}, ...
					'InitialTransformation', TFormDown{t-1} ... % use last frame transformation as a starting guess
					);
			end					
			corrfull(t,3) = FrameToFrameCorr( FixedImage, FullReg );
			
			% as a fallback option: try to directly apply the best t-form
			% from the downscaled version (from the last frame), and add it to the last frames' full
			% transformation (sometimes this is better than just
			% using it as an input to the full-reg):
			
			TFormDown_t_minus1_inv 	= TFormDown{t-1}.invert;
			AlternativeT	= affine3d( TFormDown{t}.T * TFormDown_t_minus1_inv.T * TForm{t-1}.T );	
			Fallback		= imwarp( This, ReferenceObject, AlternativeT, 'outputview', ReferenceObject );
			%Fallback		= imwarp( This, ReferenceObject, TFormDown{t}, 'outputview', ReferenceObject );			
			corrfull(t,4)	= FrameToFrameCorr( FixedImage, Fallback );
			if corrfull(t,4)>corrfull(t,3)
				warning( ['t=' num2str(t) 'fallback option is better than full-size-Reg!'] );
				FullReg		= Fallback;
				FullTForm	= TFormDown{t};
			end
			
			% output to the second subplot!
			figure(hf); hold off;
			plot(corrfull(:,1:2), '--'); hold on;
			plot(BestCorr, '--'); 
			plot(corrfull(:,3:end));
			set(gca, 'yscale','log');
			ylim([exp(-.5) 1.01]);
			xlim([1 size(Stack, 4)]);
			ylabel('frame correlation $c(t,t+1)$');
			xlabel('time $t$ [frames]');
			legend( {'unreg vs. unreg', 'unreg vs. reg', 'best algo (small)', 'best algo (full-size)', 'best t-form (small) fallback'}, 'location', 'southwest');
			titleleft('apply best algorithm to full-size stack');
			
			FixedImage	= FullReg;
			TForm{t}	= FullTForm;
		else
			% only first frame
			corrfull(1,1:4) = 1;
			FixedImage	= This;
			TForm{1}	= affine3d;
		end
		
		OldImage	= This;
		% format y,x,z,t
		RegisteredFullStack(:,:,:,t) = FixedImage(:,:,1+AdditionalPlanes:end-AdditionalPlanes);

        waitbar(t/(size(Stack, 4)-1));
	end
    delete(waitbar(0));
	toc;
	
	
% 	ReferenceObjectFull		= imref3d(size(squeeze(Stack(:,:,:,1))), MetaData.ScaleX, MetaData.ScaleY, MetaData.ScaleZ);
%     ScaleUp = [1/DownScaling 0 0 0; 0 1/DownScaling 0 0; 0 0 1 0; 0 0 0 1];
%     ScaleDown = [DownScaling 0 0 0; 0 DownScaling 0 0; 0 0 1 0; 0 0 0 1];
%     for t=1:size(Stack,4)
%        TFormScaled = affine3d( ScaleDown*TForm{t}.T*ScaleUp );
% 	   TFormScaled = affine3d( ScaleDown*TForm{t}.T );
%    	   TFormScaled = affine3d( TForm{t}.T );
% 	   RegisteredFullStack(:,:,:,t) = imwarp( squeeze(Stack(:,:,:,t)), ReferenceObjectFull, TFormScaled, 'outputview', ReferenceObjectFull );	   
%     end
%     RegisteredStack = RegisteredFullStack;

	
	% show correlations
	% frame-to-frame indicates how good the stabilization worked
	subplot 313; 
	[~, AC(:,1), ~] = StackAutoCorrelation( Stack );
	[~, AC(:,2), ~] = StackAutoCorrelation( RegisteredDownScaled );    
	[~, AC(:,3), DT] = StackAutoCorrelation( RegisteredFullStack );
	plot( DT, AC );
	legend( 'Pre-registered stack', 'Downscaled, registered', 'Registered, full stack', 'location', 'southwest' );
	ylabel('full autocorr $c(\Delta t)$');
	xlabel('frame lag $\Delta t$ [frames]');
    set(gca, 'YScale', 'log');
	ylim([exp(-1) 1.01]);
	titleleft('temporal autocorrelation');

	ExportFigure( hf, [MetaData.FileName(1:end-8) '-Reg'], [16 16], false );
    %close(hf);
	
	
	% function output
	RegisteredStack = RegisteredFullStack;
	disp( ['REGISTRATION of ' MetaData.FileName 'done.' ] );
	
	
	function corr = FrameToFrameCorr( Frame1, Frame2 )
		
		% exclude out-of-Knoedl area from correlation
		if strcmp(class(This),'uint8')
			NaNthresh	= 5;
			Frame1( Frame1<NaNthresh ) = NaN;
			Frame2( Frame2<NaNthresh ) = NaN;
		else % relativized stack:
			Frame1( Frame1==0 ) = NaN;
			Frame2( Frame2==0 ) = NaN;
		end			
		
		% then go to L2-Norm
		Frame1 = StackL2Norm( Frame1 );
		Frame2 = StackL2Norm( Frame2 );

		corr		= nansum( Frame1(:).*Frame2(:) );
	end


end


