\name{subset-methods}
\docType{methods}
\alias{subset}
\alias{subset,scidb-method}
\alias{subset,scidbdf-method}
\alias{subset,scidbexpr-method}
\title{Methods for Function \code{subset} in Package \pkg{scidb}}
\description{
SciDB \code{filter} operations.
}
\usage{
\S4method{subset}{scidb}(X,expr,eval)
\S4method{subset}{scidbdf}(X,expr,eval)
\S4method{subset}{scidbexpr}(X,expr,eval)
}
\arguments{
  \item{X}{A \code{scidb}, \code{scidbdf}, or \code{scidexpr} object.}
  \item{expr}{A character string representing a SciDB filter expression.}
  \item{eval}{(Optional) If true, execute the query and return a \code{scidb} or \code{scidbdf} object. Otherwise defer evaluation and return a \code{scidbexpr} object. By default, \code{eval} is set to defer evaluation only when called from functions in the \pkg{scidb} package.}
}
\details{
XXX
}
\note{
We use the function name \code{subset} because the R function \code{subset} closely matches the native functionality of the SciDB operator named \code{filter}. The R \code{filter} function is an unrelated timeseries function.
}
\value{A \code{scidb}, \code{scidbdf}, or \code{scidbexpr} reference object depending on the input type and value of \code{eval}. }
\author{
B. W. Lewis <blewis@paradigm4.com>
}
\examples{
\dontrun{
# Example
}
}