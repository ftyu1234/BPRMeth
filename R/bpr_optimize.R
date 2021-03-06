#' @name bpr_optimize
#' @rdname bpr_optimize
#' @aliases bpr_optimise
#'
#' @title Optimize BPR negative log likelihood function
#'
#' @description The function bpr_optimize minimizes the negative log likelihood
#'   of the BPR function. Since it cannot be evaluated analytically, an
#'   optimization procedure is used. The \code{\link[stats]{optim}} packages is
#'   used for performing optimization.
#'
#' @param x The input object, either a \code{\link[base]{matrix}} or a
#'   \code{\link[base]{list}}.
#' @param ... Additional parameters.
#' @param w A vector of parameters (i.e. coefficients of the basis functions)
#' @param basis A 'basis' object. E.g. see \code{\link{create_rbf_object}}.
#' @param fit_feature Return additional feature on how well the profile fits the
#'   methylation data. Either NULL for ignoring this feature or one of the
#'   following: 1) "RMSE" for returning the fit of the profile using the RMSE as
#'   measure of error or 2) "NLL" for returning the fit of the profile using
#'   the Negative Log Likelihood as measure of error.
#' @param cpg_dens_feat Logical, whether to return an additional feature for the
#'   CpG density across the promoter region.
#' @param opt_method The optimization method to be used. See
#'   \code{\link[stats]{optim}} for possible methods. Default is "CG".
#' @param opt_itnmax Optional argument giving the maximum number of iterations
#'   for the corresponding method. See \code{\link[stats]{optim}} for details.
#' @param is_parallel Logical, indicating if code should be run in parallel.
#' @param no_cores Number of cores to be used, default is max_no_cores - 2.
#'
#' @return Depending on the input object \code{x}: \itemize{\item{If \code{x} is
#'   a \code{\link[base]{list}}:}  An object containing the following elements:
#'   \itemize{ \item{ \code{W_opt}: An Nx(M+1) matrix with the optimized
#'   parameter values. Each row of the matrix corresponds to each element of the
#'   list x. The columns are of the same length as the parameter vector w (i.e.
#'   number of basis functions). } \item{ \code{Mus}: An N x M matrix with the
#'   RBF centers if basis object is \code{\link{create_rbf_object}}, otherwise
#'   NULL.} \item{ \code{basis}: The basis object. } \item{ \code{w}: The
#'   initial values of the parameters w. } } \item{If \code{x} is a
#'   \code{\link[base]{matrix}}:} An object containing the following elements:
#'   \itemize{ \item{ \code{w_opt}: Optimized values for the coefficient vector
#'   w. The length of the result is the same as the length of the vector w. }
#'   \item{ \code{basis}: The basis object. } }}
#'
#' @author C.A.Kapourani \email{C.A.Kapourani@@ed.ac.uk}
#'
#' @seealso \code{\link{create_basis}}, \code{\link{eval_functions}}
NULL


#' @rdname bpr_optimize
#'
#' @examples
#' # Example of optimizing parameters for synthetic data using default values
#' data <- meth_data
#' out_opt <- bpr_optim(x = data, is_parallel = FALSE, opt_itnmax = 10)
#'
#' #-------------------------------------
#'
#' @export
bpr_optim <- function(x, ...){
    UseMethod("bpr_optim")
}


# Default function for the generic function 'bpr_optim'
bpr_optim.default <- function(x, ...){
    stop("Object x should be either matrix or list!")
}


#' @rdname bpr_optimize
#'
#' @examples
#' # Example of optimizing parameters for synthetic data using 3 RBFs
#' ex_data <- meth_data
#' basis <- create_rbf_object(M=3)
#' out_opt <- bpr_optim(x = ex_data, is_parallel = FALSE, basis = basis,
#'                      opt_itnmax = 10)
#'
#' #-------------------------------------
#'
#' @export
bpr_optim.list <- function(x, w = NULL, basis = NULL, fit_feature = "RMSE",
                           cpg_dens_feat = TRUE, opt_method = "CG",
                           opt_itnmax = 100, is_parallel = TRUE,
                           no_cores = NULL, ...){
    # Check that x is a list object
    assertthat::assert_that(is.list(x))

    # Extract number of observations
    N <- length(x)
    assertthat::assert_that(N > 0)

    # Perform checks for initial parameter values
    out <- .do_checks(w = w, basis = basis)
    w   <- out$w
    basis <- out$basis

    # Initialize so the CMD check on R passes without NOTES
    i <- 0

    # If parallel mode is ON
    if (is_parallel){
        # If number of cores is not given
        if (is.null(no_cores)){
            no_cores <- parallel::detectCores() - 2
        }else{
            if (no_cores >= parallel::detectCores()){
                no_cores <- parallel::detectCores() - 1
            }
        }
        if (is.na(no_cores)){
            no_cores <- 2
        }
        # Create cluster object
        cl <- parallel::makeCluster(no_cores)
        doParallel::registerDoParallel(cl)

        # Parallel optimization for each element of x, i.e. for each region i.
        res <- foreach::"%dopar%"(obj = foreach::foreach(i = 1:N),
              ex  = {
                  out_opt <- bpr_optim.matrix(x           = x[[i]],
                                              w           = w,
                                              basis       = basis,
                                              fit_feature = fit_feature,
                                              cpg_dens_feat = cpg_dens_feat,
                                              opt_method  = opt_method,
                                              opt_itnmax  = opt_itnmax)
              })
        # Stop parallel execution
        parallel::stopCluster(cl)
        doParallel::stopImplicitCluster()
    }else{
        # Sequential optimization for each element of x, i.e. for each region i.
        res <- foreach::"%do%"(obj = foreach::foreach(i = 1:N),
               ex  = {
                   out_opt <- bpr_optim.matrix(x           = x[[i]],
                                               w           = w,
                                               basis       = basis,
                                               fit_feature = fit_feature,
                                               cpg_dens_feat = cpg_dens_feat,
                                               opt_method  = opt_method,
                                               opt_itnmax  = opt_itnmax)
               })
    }

    # Matrix for storing optimized coefficients
    W_opt <- sapply(res, function(x) x$w_opt)
    if (is.matrix(W_opt)){
        W_opt <- t(W_opt)
    }else{
        W_opt <- as.matrix(W_opt)
    }
    colnames(W_opt) <- paste("w", seq(1, NCOL(W_opt)), sep = "")

    # Matrix for storing the centers of RBFs if object class is 'rbf'
    Mus <- NULL
    if (methods::is(basis, "rbf")){
        if (is.null(basis$mus)){
            Mus <- sapply(lapply(res, function(x) x$basis), function(y) y$mus)
            if (is.matrix(Mus)){
                Mus <- t(Mus)
            }else{
                Mus <- as.matrix(Mus)
            }
            colnames(Mus) <- paste("mu", seq(1, NCOL(Mus)), sep = "")
        }
    }

    return(list(W_opt = W_opt,
                Mus = Mus,
                basis = basis,
                w = w))
}


#' @rdname bpr_optimize
#'
#' @examples
#' # Example of of specific promoter region using 2 RBFs
#' basis <- create_rbf_object(M=2)
#' w <- c(0.1, 0.1, 0.1)
#' data <- meth_data[[1]]
#' out_opt <- bpr_optim(x = data, w = w, basis = basis, fit_feature = "NLL",
#'                      opt_itnmax = 10)
#'
#' @importFrom stats optim
#'
#' @export
bpr_optim.matrix <- function(x, w = NULL, basis = NULL, fit_feature = "RMSE",
                             cpg_dens_feat = TRUE, opt_method = "CG",
                             opt_itnmax = 100, ...){
    # Vector for storing CpG locations relative to TSS
    obs <- as.vector(x[, 1])

    # Methylation data
    data <- x[, 2:3]

    # Create design matrix H
    des_mat <- .design_matrix(x = basis, obs = obs)
    H       <- des_mat$H
    basis   <- des_mat$basis

    # Call optim function to perform minimization of the NLL of BPR function
    w_opt <- optim(par     = w,
                   fn      = .bpr_likelihood,
                   gr      = .bpr_gradient,
                   method  = opt_method,
                   control = list(maxit = opt_itnmax),
                   H       = H,
                   data    = data,
                   is_NLL  = TRUE)$par

    if (basis$M != 0){
        # If we need to add the goodness of fit to the data as feature
        if (!is.null(fit_feature)){
            if (identical(fit_feature, "NLL")){
                fit <- .bpr_likelihood(w = w_opt,
                                       H = H,
                                       data = data,
                                       is_NLL = TRUE)
            }else if (identical(fit_feature, "RMSE")){
                # Predictions of the target variables
                f_pred <- as.vector(pnorm(H %*% w_opt))
                f_true <- data[, 2] / data[, 1]
                fit <- sqrt(mean( (f_pred - f_true) ^ 2) )
            }
            w_opt <- c(w_opt, fit)
        }

        # Add as feature the CpG density in the promoter region
        if (cpg_dens_feat){
            w_opt <- c(w_opt, length(obs))
        }
    }

    return(list(w_opt = w_opt,
                basis = basis))
}


# Internal function to make all the appropriate type checks.
.do_checks <- function(w = NULL, basis = NULL){
    if (is.null(basis)){
        basis <- create_rbf_object(M = 3)
    }
    if (is.null(w)){
        w <- rep(0.5, basis$M + 1)
    }
    if (length(w) != (basis$M + 1) ){
        stop("Coefficient vector should be M+1, M: number of basis functions!")
    }
    return(list(w = w, basis = basis))
}
