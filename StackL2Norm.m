function StackL2 = StackL2Norm( Stack )
% takes a 4D (x,y,z,t) one channel stack (like Tracking data) and returns
% one that is L2-normed (single data)


    % normiere auf L2 norm
    for t=1:size(Stack,4)   
		% do per time step
		vol = single(Stack(:,:,:,t)); 		
		% relativize to mean value
		vol = vol - nanmean(vol(:));	
		% norm to 1
        StackL2(:,:,:,t) = vol / sqrt(nansum(vol(:).^2));
    end

end