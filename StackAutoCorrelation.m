
function [FrameToFrameCorr, AutoCorr, DeltaT] = StackAutoCorrelation( Stack )

	Stack = single(Stack);

	% Threshold: Parts out of spheroid shouldnt count for correlation (they
	% always correlate 100%)
	NaNthresh	= 5;
	Stack( Stack<NaNthresh ) = NaN;

	% then go to L2-Norm
    StackL2 = StackL2Norm( Stack );

	
	% Stop - check
	for t=2:size(Stack,4)
		% mache frame-to-frame correlation
		
		This		= StackL2(:,:,:,t);
		Previous	= StackL2(:,:,:,t-1);		
		%This		= This - mean(This(:));
		%Previous	= Previous - mean(Previous(:));
		FrameToFrameCorr(t-1)		= nansum( This(:).*Previous(:) );
	end
	
   
	% mache full auto correlation
    DeltaT = 0:(size(Stack,4))/2;
	for dt=DeltaT
		Stack1		= StackL2(:,:,:,1+dt:end);
		Stack2      = StackL2(:,:,:,1:end-dt);
        NumberOfCorrelatedFrames = size(Stack1,4);
        AutoCorr(1+dt) = (nansum(Stack1(:).*Stack2(:))) / NumberOfCorrelatedFrames;
	end
    
end