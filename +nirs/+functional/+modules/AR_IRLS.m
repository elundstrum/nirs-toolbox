classdef AR_IRLS < nirs.functional.AbstractModule
    %UNTITLED3 Summary of this class goes here
    %   Detailed explanation goes here
  
    properties
        hpf_Fc = 1/125;
        basis = {};
        constant = true;
    end
    
    methods

        function obj = AR_IRLS( prevJob )
           obj.name = 'GLM via AR(P)-IRLS';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function stats = execute( obj, data )
            for i = 1:length(data)
                
                d = data(i).data;
                t = data(i).time;
                Fs = data(i).Fs;
                
                % generate design matrix
                stims = data(i).stimulus;
                [X, names] = nirs.functional. ...
                    generateDesignMatrix( stims, t, obj.basis );
                
                % generate baseline/trend regressors
                C = nirs.functional.dctmtx( t, obj.hpf_Fc );
                
                if obj.constant == false;
                    C = C(:,2:end);
                end
                
                for j = 1:size(C,2)
                    names{end+1} = ['dct_' num2str(j)];
                end
                
                % check rank
                if isinf( cond(X) )
                    error( 'Design matrix is rank deficient.' )
                end
                
                % check condition
                maxCond = 30; 
                if cond([X C]) > maxCond
                    warning('Lowering HPF cutoff to improve condition of design matrix.')
                end
                
                while cond([X C]) > maxCond && ~isempty(C)
                    C(:,end) = [];
                    names = names(1:end-1);
                end
                                
                % call ar_irls
                S(i) = nirs.external.ar_irls.ar_irls( d, [X C], 4*Fs );
                S(i).X = X;
                S(i).C = C;
                S(i).names = names';
                
                % output stats
                stats = S;
                
            end
        end
        
        function options = getOptions( obj )
            options = [];
        end
           
        function obj = putOptions( obj, options )
        end
        
    end
    
end

