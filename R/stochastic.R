#' Generate many  matrices from a stochastic forcing
#' @param force.vec sequence of numbers to force with
#' @param base.matrix matrix upon which to perform forcing
#' @param element.mask elements on which to operate can be matrix of logicals or ONE index i, j
#' @param force.fxn forcing function: see details
#' @details The function force.fxn(forcing, elements) will take the elements of force.vec and
#' elements as its arguments, and return a new vector representing the forced elements
#' @export
GenStoch <- function(force.vec, base.matrix, element.mask, force.fxn){

  if(is.null(dim(base.matrix)))
    stop("need to supply a matrix to base.matrix")
  d <- dim(base.matrix)[1]
  if(d != dim(base.matrix)[2])
    stop("need to supply a square matrix to base.matrix")
  if(is.null(dim(element.mask)) && length(element.mask) != 2)
    stop("element.mask needs to be either a vector of length 2 giving indices, or a logical matrix")
  if(!is.null(dim(element.mask)) && dim(element.mask) != dim(base.matrix))
    stop("element.mask needs to have same dimension as base.matrix")
  if(length(element.mask) == 2){
    i <- element.mask[1]
    j <- element.mask[2]
    element.mask <- outer(1:d, 1:d, function(x,y){ ifelse(x==i & y==j, TRUE, FALSE)})
  }

  s <- length(force.vec)
  output <- matrix(d^2, s ) # allocate a matrix of appropriate size for output
  elements <- base.matrix[element.mask]
  output <- sapply(force.vec, function(x){ base.matrix[element.mask] <- force.fxn(x, elements);
                                           return(c(base.matrix))
                                         })
  return(output)
}

#' Project population growth of all age classes in a stochastic environment after fixed time
#' @param n.0 initial number in stages
#' @param matrices is a d^2 x s matrix, where d number of stages, s the number of matrixes
#' @param p vector of probabilities for drawing each matrix
#' @param t.max time to stop and compute population size
#' @param qe quasi-extinction threshold
#' @examples
#' A1 = matrix(c(0,1,.5,0), nrow=2)
#' A2 = matrix(c(0,2,.5,0), nrow=2)
#' A3 = matrix(c(0,7,.5,0), nrow=2)
#' ## d=2 stages, to generating appropriate d^2 by 3 matrix for input...
#' d = 2
#' mats = c(A1, A2, A3) # s = 3
#' dim(mats) = c(d^2, length(mats)/d^2)
#' Project.iid(matrix(1, d, 1), mats, rep(1/3, 3), 10)
#' @export
Project.iid <- function(n.0, matrices, p, t.max, qe=0){
  mat.dim <- dim(matrices)
  s <- mat.dim[2]
  d <- sqrt(mat.dim[1])
  if (length(p) != s)
    stop("need value p for each matrix")
  if (sum(p) != 1)
    stop("p must sum to 1")
  # generate t.max random matrix indices
  A.indices <- sample(1:s, size=t.max, prob=p, replace=TRUE)
  n <- n.0
  for(t in seq_along(A.indices)){
    i <- A.indices[t] # extract appropriate index
    A <- matrices[,i]
    dim(A) <- c(d,d) #reshape
    n <- A%*%n # project population 1 period aheadg
    if(sum(n) < qe)
      return(t) #return the time of extinction
  }
  if (qe == 0) 
    return(n) ##
  if (qe > 0)
    return(t.max+1)
}

#' Compute the stochastic growth rate in an iid stochastic environment 
#' @param matrices is a d^2 x s matrix, where d number of stages, s the number of matrixes
#' @param p vector of probabilities for drawing each matrix
#' @param t.max timeframe over which to compute growth rate
#' @examples
#' A1 = matrix(c(0,1,.5,0), nrow=2)
#' A2 = matrix(c(0,2,.5,0), nrow=2)
#' A3 = matrix(c(0,7,.5,0), nrow=2)
#' ## d=2 stages, to generating appropriate d^2 by 3 matrix for input...
#' d = 2
#' mats = c(A1, A2, A3) # s = 3
#' dim(mats) = c(d^2, length(mats)/d^2)
#' Growth.iid(mats, rep(1/3, 3), 10)
#' @export
Growth.iid <- function(matrices, p, t.max){
  mat.dim <- dim(matrices)
  s <- mat.dim[2]
  d <- sqrt(mat.dim[1])
  if (length(p) != s)
    stop("need value p for each matrix")
  if (sum(p) != 1)
    stop("p must sum to 1")
  # generate t.max random matrix indices
  A.indices <- sample(1:s, size=t.max, prob=p, replace=TRUE)
  n <- matrix(1, d, 1) ## set initial population at 1 in each stage for convenient compuation
  lyap <- numeric(t.max)
  for(t in seq_along(A.indices)){
    i <- A.indices[t] # extract appropriate index
    A <- matrices[,i]
    dim(A) <- c(d,d) #reshape

    tmp <- A%*%n # project population 1 period ahead 
    lyap[t] <- log(tmp[1]/n[1])
    n <- tmp/tmp[1] #rescale
  }
  return(mean(lyap))
}

#' Compute distribution of total populations after fixed time
#' @param n.0 initial number in stages
#' @param matrices is a d^2 x s matrix, where d number of stages, s the number of matrixes
#' @param p vector of probabilities for drawing each matrix
#' @param t.max time to stop and compute population size
#' @param N number of replicates to compute the distribution over
#' @details Should include a weighting/masking vector for totals in one class only
#' @export
Totals.iid <- function(n.0, matrices, p, t.max, N){
  out<- numeric(N)
  out <- sapply(out, function(z){ z=0;  sum(Project.iid(n.0, matrices, p, t.max))})
  return(out)
}

#' Compute distribution of times to quasi-extinction
#' @param n.0 initial number in stages
#' @param matrices is a d^2 x s matrix, where d number of stages, s the number of matrixes
#' @param p vector of probabilities for drawing each matrix
#' @param t.max time to stop and compute population size
#' @param N number of replicates to compute the distribution over
#' @param qe quasi-extinction threshold 
#' @export
ExitTimes.iid <- function(n.0, matrices, p, t.max, N, qe=0){
  if (qe == 0)
    stop("quasi extinction threshold must be greater than 0")
  if (qe >= sum(n.0))
    stop("quasi extinction threshold must be below starting population sum(n.0)")
  out <- numeric(N)
  out <- sapply(out, function(z){ z=0; Project.iid(n.0, matrices, p, t.max, qe)})
  return(out)
}

#' Compute cdf for probability of extinction versus time
#' @param n.0 initial number in stages
#' @param matrices is a d^2 x s matrix, where d number of stages, s the number of matrixes
#' @param p vector of probabilities for drawing each matrix
#' @param t.max time to stop and compute population size
#' @param N number of replicates to compute the distribution over
#' @param qe quasi-extinction threshold
#' @details wrapper for ecdf function
#' returns a function
#' @export
Exit.cdf.iid <- function(n.0, matrices, p, t.max, N, qe=0){
 return(ecdf(ExitTimes.iid(n.0=n.0, matrices=matrices, p=p, t.max=t.max, N=N, qe=qe)))
}

#' Compute confidence interval for probability of extinction within specified timeframe
#' @param time time at which to calculate CI
#' @param ci.width width (in probability units) of confidence interval to produce
#' @param reps number of distinct cdfs to compute, don't make this too large
#' @param n.0 initial number in stages
#' @param matrices is a d^2 x s matrix, where d number of stages, s the number of matrixes
#' @param p vector of probabilities for drawing each matrix
#' @param t.max time to stop and compute population size
#' @param N number of replicates to compute the exit time distribution over within each run
#' @param qe quasi-extinction threshold
#' @details This MAY NOT fully represent the variablity in the system this function does not
#' use distribution of vital rates, but rather repeated draws of complete matrices.
#' See Fieberg and Ellner (2003, Ecology) and Morris and Doak (2003).
#' @export
Exit.ci.iid <- function(time, ci.width, reps, n.0, matrices, p, t.max, N, qe=0){
  extinction.prob <- sapply(numeric(reps),
                            function(z){ z <- 0;
                                         emp.cdf <- Exit.cdf.iid(n.0, matrices, p, t.max, N, qe);
                                         emp.cdf(time)}
                            )
  return(CI(extinction.prob, width=ci.width))
}
