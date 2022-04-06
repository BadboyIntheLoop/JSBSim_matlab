function out = test_fcn(in)
	in.control = in.control + 1;
	fprintf('After Increase: %d \n',  in.control);
end
