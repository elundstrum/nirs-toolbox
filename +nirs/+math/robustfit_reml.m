function varargout = robustfit_reml(X,y,wfun,tune,const,priorw,dowarn)
%ROBUSTFIT Robust linear regression
%   B = ROBUSTFIT(X,Y) returns the vector B of regression coefficients,
%   obtained by performing robust regression to estimate the linear model
%   Y = Xb.  X is an n-by-p matrix of predictor variables, and Y is an
%   n-by-1 vector of observations.  The algorithm uses iteratively
%   reweighted least squares with the bisquare weighting function.  By
%   default, ROBUSTFIT adds a column of ones to X, corresponding to a
%   constant term in the first element of B.  Do not enter a column of ones
%   directly into the X matrix.
%
%   B = ROBUSTFIT(X,Y,'WFUN',TUNE) uses the weighting function 'WFUN' and
%   tuning constant TUNE.  'WFUN' can be any of 'andrews', 'bisquare',
%   'cauchy', 'fair', 'huber', 'logistic', 'talwar', or 'welsch'.
%   Alternatively 'WFUN' can be a function that takes a residual vector as
%   input and produces a weight vector as output.  The residuals are scaled
%   by the tuning constant and by an estimate of the error standard
%   deviation before the weight function is called.  'WFUN' can be
%   specified using @ (as in @myfun).  TUNE is a tuning constant that is
%   divided into the residual vector before computing the weights, and it
%   is required if 'WFUN' is specified as a function.
% 
%   B = ROBUSTFIT(X,Y,'WFUN',TUNE,'CONST') controls whether or not the
%   model will include a constant term.  'CONST' is 'on' (the default) to
%   include the constant term, or 'off' to omit it.
%
%   [B,STATS] = ROBUSTFIT(...) also returns a STATS structure
%   containing the following fields:
%       'ols_s'     sigma estimate (rmse) from least squares fit
%       'robust_s'  robust estimate of sigma
%       'mad_s'     MAD estimate of sigma; used for scaling
%                   residuals during the iterative fitting
%       's'         final estimate of sigma, the larger of robust_s
%                   and a weighted average of ols_s and robust_s
%       'se'        standard error of coefficient estimates
%       't'         ratio of b to stats.se
%       'p'         p-values for stats.t
%       'covb'      estimated covariance matrix for coefficient estimates
%       'coeffcorr' estimated correlation of coefficient estimates
%       'w'         vector of weights for robust fit
%       'h'         vector of leverage values for least squares fit
%       'dfe'       degrees of freedom for error
%       'R'         R factor in QR decomposition of X matrix
%
%   The ROBUSTFIT function estimates the variance-covariance matrix of the
%   coefficient estimates as V=inv(X'*X)*STATS.S^2.  The standard errors
%   and correlations are derived from V.
%
%   ROBUSTFIT treats NaNs in X or Y as missing values, and removes them.
%
%   Example:
%      x = (1:10)';
%      y = 10 - 2*x + randn(10,1); y(10) = 0;
%      bls = regress(y,[ones(10,1) x])
%      brob = robustfit(x,y)
%      scatter(x,y)
%      hold on
%      plot(x,brob(1)+brob(2)*x,'r-', x,bls(1)+bls(2)*x,'m:')
%
%   See also REGRESS, ROBUSTDEMO.

% References:
%   DuMouchel, W.H., and F.L. O'Brien (1989), "Integrating a robust
%     option into a multiple regression computing environment,"
%     Computer Science and Statistics:  Proceedings of the 21st
%     Symposium on the Interface, American Statistical Association.
%   Holland, P.W., and R.E. Welsch (1977), "Robust regression using
%     iteratively reweighted least-squares," Communications in
%     Statistics - Theory and Methods, v. A6, pp. 813-827.
%   Huber, P.J. (1981), Robust Statistics, New York: Wiley.
%   Street, J.O., R.J. Carroll, and D. Ruppert (1988), "A note on
%     computing robust regression estimates via iteratively
%     reweighted least squares," The American Statistician, v. 42,
%     pp. 152-154.

%   Copyright 1993-2011 The MathWorks, Inc.


if  nargin < 2      
    error(message('stats:robustfit:TooFewInputs'));      
end 

if (nargin<3 || isempty(wfun)), wfun = 'bisquare'; end
if nargin<4, tune = []; end
[wfun,tune] = statrobustwfun(wfun,tune);
if (nargin<5), const='on'; end
switch(const)
 case {'on' 1},  doconst = 1;
 case {'off' 0}, doconst = 0;
 otherwise,  error(message('stats:robustfit:BadConst'));
end
if nargin<6
    priorw = ones(size(y));
end
if nargin<7
    dowarn = true;
end

varargout=cell(1,max(1,nargout));
[varargout{:}] = statrobustfit(X,y,wfun,tune,[],doconst,priorw,dowarn);




function [b,stats] = statrobustfit(X,y,wfun,tune,wasnan,addconst,priorw,dowarn)
%STATROBUSTFIT Calculation function for ROBUSTFIT

% Copyright 1993-2015 The MathWorks, Inc.


% Must check for valid function in this scope
c = class(wfun);
fnclass = class(@wfit);
if (~isequal(c,fnclass) && ~isequal(c,'inline') ...
    && (~isequal(c,'char') || isempty(which(wfun))))
   error(message('stats:robustfit:BadWeight'));
end

[n,p] = size(X);
if (addconst)
   X = [ones(n,1) X];
   p = p+1;
end
if (n<=p)
   error(message('stats:robustfit:NotEnoughData'));
end

if ~all(priorw==1)
    sw = sqrt(priorw);
    X = bsxfun(@times,X,sw);
    y = y.*sw;
else
    sw = 1;
end

% Find the least squares solution.
[Q,R,perm] = qr(X,0);
if isempty(R) % can only happen if p=0 as we know n>p>=0
    tol = 1;
else
    tol = abs(R(1)) * max(n,p) * eps(class(R));
end
xrank = sum(abs(diag(R)) > tol);
if xrank==p
    b(perm,:) = R \ (Q'*y);
else
    % Use only the non-degenerate parts of R and Q, but don't reduce
    % R because it is returned in stats and is expected to be of
    % full size.
    if dowarn
        warning(message('stats:robustfit:RankDeficient', xrank));
    end
    b(perm,:) = [R(1:xrank,1:xrank) \ (Q(:,1:xrank)'*y); zeros(p-xrank,1)];
    perm = perm(1:xrank);
end
b0 = zeros(size(b));

% Adjust residuals using leverage, as advised by DuMouchel & O'Brien
E = X(:,perm)/R(1:xrank,1:xrank);
h = min(.9999, sum(E.*E,2));
adjfactor = 1 ./ sqrt(1-h);

dfe = n-xrank;
ols_s = norm((y-X*b)./sw) / sqrt(dfe);

% If we get a perfect or near perfect fit, the whole idea of finding
% outliers by comparing them to the residual standard deviation becomes
% difficult.  We'll deal with that by never allowing our estimate of the
% standard deviation of the error term to get below a value that is a small
% fraction of the standard deviation of the raw response values.
tiny_s = 1e-6 * std(y);
if tiny_s==0
    tiny_s = 1;
end

% Perform iteratively re-weighted least squares to get coefficient estimates
D = sqrt(eps(class(X)));
iter = 0;
iterlim = 50;
wxrank = xrank;    % rank of weighted version of x
while((iter==0) || any(abs(b-b0) > D*max(abs(b),abs(b0))))
   iter = iter+1;
   if (iter>iterlim)
      warning(message('stats:statrobustfit:IterationLimit'));
      break;
   end
   
   % Compute residuals from previous fit, then compute scale estimate
   r = y - X*b;
   radj = r .* adjfactor ./ sw;
   s = madsigma(radj,wxrank);
   
   % Compute new weights from these residuals, then re-fit
   w = feval(wfun, radj/(max(s,tiny_s)*tune));
   b0 = b;
   [b(perm),covb(perm,perm),dfe] = wfit(y,X(:,perm),w);
end

if (nargout>1)
   r = y - X*b;
   radj = r .* adjfactor ./ sw;
   % Save everything
   stats.sigma=s;
   stats.resid = r;
   stats.rstud = r .* adjfactor / s;
   stats.se = sqrt(diag(covb));
   stats.covb = covb;
   stats.t = NaN(size(b));
   stats.t(stats.se>0) = b(stats.se>0) ./ stats.se(stats.se>0);
   stats.p = 2 * tcdf(-abs(stats.t), dfe);
   stats.w = w;
   stats.dfe = dfe;
end

% -----------------------------
function [b,covB,dfe] = wfit(Y,X,w)
%WFIT    weighted least squares fit


ncomp=size(X,2);
formula='Y~-1';
for i=1:ncomp
    formula=[formula '+X' num2str(i)];
end
for i=1:ncomp
    formula=[formula '+(1|Z' num2str(i) ')'];
end

% This is the dumbest thing, but matlab will throw an error if the
% length(#)< length(unique(#)) where it rounds to only 5 digits for floats.    
Z=X;
tbl2=array2table(Z);
for i=1:ncomp
    tbl2.(['Z' num2str(i)])=strtrim(cellstr(num2str(tbl2.(['Z' num2str(i)]))));
end


tbl=array2table(X);
tbl.Y=Y;
tbl=[tbl tbl2];
lme=fitlme(tbl,formula,'fitmethod','REML','Weight',w);

b=lme.Coefficients.Estimate;
covB=lme.CoefficientCovariance;

dfe=lme.DFE;


% -----------------------------
function s = madsigma(r,p)
%MADSIGMA    Compute sigma estimate using MAD of residuals from 0
rs = sort(abs(r));
s = median(rs(max(1,p):end)) / 0.6745;





function [wfun,tune] = statrobustwfun(wfun,tune)
%STATROBUSTWFUN Get robust weighting function and tuning constant

% Copyright 2005-2007 The MathWorks, Inc.


% Convert name of weight function to a handle to a local function, and get
% the default value of the tuning parameter
t = [];
if ischar(wfun)
    switch(wfun)
        case 'andrews'
            wfun = @andrews;
            t = 1.339;
        case 'bisquare'
            wfun = @bisquare;
            t = 4.685;
        case 'cauchy'
            wfun = @cauchy;
            t= 2.385;
        case 'fair'
            wfun = @fair;
            t = 1.400;
        case 'huber'
            wfun = @huber;
            t = 1.345;
        case 'logistic'
            wfun = @logistic;
            t = 1.205;
        case 'ols'
            wfun = @ols;
            t = 1;
        case 'talwar'
            wfun = @talwar;
            t = 2.795;
        case 'welsch'
            wfun = @welsch;
            t = 2.985;
    end
end

% Use the default tuning parameter or check the supplied one
if isempty(tune)
    if isempty(t)
        tune = 1;
    else
        tune = t;
    end
elseif (tune<=0)
    m = message('stats:statrobustwfun:BadTuningConstant');
    throwAsCaller(MException(m.Identifier, '%s', getString(m)));
end
     
% --------- weight functions

function w = andrews(r)
r = max(sqrt(eps(class(r))), abs(r));
w = (abs(r)<pi) .* sin(r) ./ r;

function w = bisquare(r)
w = (abs(r)<1) .* (1 - r.^2).^2;

function w = cauchy(r)
w = 1 ./ (1 + r.^2);

function w = fair(r)
w = 1 ./ (1 + abs(r));

function w = huber(r)
w = 1 ./ max(1, abs(r));

function w = logistic(r)
r = max(sqrt(eps(class(r))), abs(r));
w = tanh(r) ./ r;

function w = ols(r)
w = ones(size(r));

function w = talwar(r)
w = 1 * (abs(r)<1);

function w = welsch(r)
w = exp(-(r.^2));



function s = statrobustsigma(wfun,r,p,s,t,h)
%STATROBUSTSIGMA Compute robust sigma estimate for robust regression
%   Used by robustfit and nlinfit.

% This function computes an s value so that s^2 * inv(X'*X) is a reasonable
% covariance estimate for robust regression coefficient estimates.  It is
% based on the references below.  The expressions in these references do
% not appear to be the same, but we have attempted to reconcile them in a
% reasonable way.
%
% Before calling this function, the caller should have computed s as the
% MAD of the residuals omitting the p-1 smallest in absolute value, as
% recommended by O'Brien and in the material below eq. 8 of Street.  The
% residuals should be adjusted by their leverage according to the
% recommendation of O'Brien.

%   DuMouchel, W.H., and F.L. O'Brien (1989), "Integrating a robust
%     option into a multiple regression computing environment,"
%     Computer Science and Statistics:  Proceedings of the 21st
%     Symposium on the Interface, American Statistical Association.
%   Holland, P.W., and R.E. Welsch (1977), "Robust regression using
%     iteratively reweighted least-squares," Communications in
%     Statistics - Theory and Methods, v. A6, pp. 813-827.
%   Huber, P.J. (1981), Robust Statistics, New York: Wiley.
%   Street, J.O., R.J. Carroll, and D. Ruppert (1988), "A note on
%     computing robust regression estimates via iteratively
%     reweighted least squares," The American Statistician, v. 42,
%     pp. 152-154.


% Copyright 2005 The MathWorks, Inc. 


% Include tuning constant in sigma value
st = s*t;

% Get standardized residuals
n = length(r);
u = r ./ st;

% Compute derivative of phi function
phi = u .* feval(wfun,u);
delta = 0.0001;
u1 = u - delta;
phi0 = u1 .* feval(wfun,u1);
u1 = u + delta;
phi1 = u1 .* feval(wfun,u1);
dphi = (phi1 - phi0) ./ (2*delta);

% Compute means of dphi and phi^2; called a and b by Street.  Note that we
% are including the leverage value here as recommended by O'Brien.
m1 = mean(dphi);
m2 = sum((1-h).*phi.^2)/(n-p);

% Compute factor that is called K by Huber and O'Brien, and lambda by
% Street.  Note that O'Brien uses a different expression, but we are using
% the expression that both other sources use.
K = 1 + (p/n) * (1-m1) / m1;

% Compute final sigma estimate.  Note that Street uses sqrt(K) in place of
% K, and that some Huber expressions do not show the st term here.
s = K*sqrt(m2) * st /(m1);
