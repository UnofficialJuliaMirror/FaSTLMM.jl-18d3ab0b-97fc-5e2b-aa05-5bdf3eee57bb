##################################################################
# Fast linear mixed models
##################################################################
#
# We implement linear mixed models for data which has covariance of
# the form tau2*K + sigma2*I, where sigma2 and tau2 are positive
# scalars, K is a symmetric positive definite "kinship" matrix and I
# is the identity matrix.
#
# Models of this type are used for GWAS and QTL mapping in structured
# populations.
#
# ################################################################

##################################################################
# rotateData: rotate by orthogonal transformation
##################################################################

"""
rotateData: Rotates data with respect to the kinship matrix

y = phenotype matrix
X = predictor matrix
K = kinship matrix, expected to be symmetric and positive definite
"""

function rotateData(y::Array{Float64,2},X::Array{Float64,2},
                    K::Array{Float64,2})

    # check dimensions
    n = size(y,1)
    if( ( size(X,1) != n ) | ( size(K,1) != n ))
        error("Dimension mismatch.")
    end

    # check symmetry and positive definiteness of K
    if( !(issym(K)) )
        error("K is not symmetric.")
    end

    if( !(isposdef(K)) )
        error("K is not positive definite.")
    end

    # spectral decomposition of a symmetric matrix
    EF = eigfact(K)

    # return rotated phenotype, covariates, and eigenvalues
    return EF[:vectors]'y, EF[:vectors]'X, EF[:values]

end

##################################################################
# wls: weighted least squares        
##################################################################        

"""
wls: Weighted least squares estimation

y = outcome, matrix
X = predictors, matrix
w = weights (should be positive), one-dim vector

The variance estimate is maximum likelihood
"""

function wls(y::Array{Float64,2},X::Array{Float64,2},w::Array{Float64,1},
             reml::Bool=false,resid=false)

    # number of individuals
    n = size(y,1)
    # number of covariates
    p = size(X,2)
    
    # check if weights are positive
    if(any(w.<=.0))
        error("Some weights are not positive.")
    end
        
    # square root of the weights
    sqrtw = sqrt(w)
    # scale by weights
    yy = y.*sqrtw
    XX = diagm(sqrtw)*X

    # QR decomposition of the transformed data
    (q,r) = qr(XX)
    yy = At_mul_B(q,yy)
    b = r\yy

    # estimate y and calculate rss
    yhat = X*b
    rss = sum(((y-yhat)./sqrtw).^2)

    if( reml )        
        sigma2 = rss/(n-p)
    else
        sigma2 = rss/n
    end
        
    # return coefficient and variance estimate
    if(resid)
        yhat = X*b
        r = y - yhat
        return b, sigma2, r
    else
        return b, sigma2
    end
end

############################################
# inverse logit function
############################################
"""
invlogit: inverse of the logit function
"""
invlogit(x::Float64) = exp(x)/(1+exp(x))

############################################
# logit function
############################################
"""
logit: logit function
"""
logit(x::Float64) = log(x/(1-x))

    
# ################################################################
# function to calculate log likelihood of data given fixed effects
# ################################################################
"""
logLik: log likelihood of data

logsigma2 = log of error variance component
y = matrix of phenotypes
X = matrix of covariates for fixed effects
d = eigenvalues of spectral decomposition
"""
function logLik(logsigma2::Float64,h2::Float64,
                y::Array{Float64,2},
                X::Array{Float64,2},
                lambda::Array{Float64,1})
    # weights
    w = h2*lambda + (1-h2)

    # calculate coefficients and rss from weighted least squares
    (b,sigma2,r) = wls(y,X,w,false,true)
    sqrtw = sqrt(w)
    rss = sum((r./w).^2)
    
    n = size(w,1)
    # get normal pdfs
    lp =  - 0.5 * rss/sigma2 - sum(log(w)) - (n/2)*log(sigma2)
    # sum to get log likelihood
    return lp[1,1]
end

    
##################################################################
# function to estimate variance components and heritability
##################################################################

"""
estVarComp: estimate variance components
"""


function estVarComp(y::Array{Float64,2},
                    X::Array{Float64,2},
                    d::Array{Float64,1},logsigma2::Float64,logith2::Float64)

    function logLik0(z::Array{Float64,1})
        -logLik(z[1],z[2],y,X,d,false)
    end

    est = optimize(logLik0,[logsigma2,logith2])
    return exp(est.minimum[1]) , invlogit(est.minimum[2])
end

##################################################################
# function to fit mixed model
##################################################################

#=
function lmm( y::Array{Float64,2}, X::Array{Float64,2},
                    d::Array{Float64,1},logsigma2::Float64,logith2::Float64)
=#
