#
#    _____      _ ____  ____
#   / ___/_____(_) __ \/ __ )
#   \__ \/ ___/ / / / / __  |
#  ___/ / /__/ / /_/ / /_/ / 
# /____/\___/_/_____/_____/  
#
#
#
# BEGIN_COPYRIGHT
#
# This file is part of SciDB.
# Copyright (C) 2008-2014 SciDB, Inc.
#
# SciDB is free software: you can redistribute it and/or modify
# it under the terms of the AFFERO GNU General Public License as published by
# the Free Software Foundation.
#
# SciDB is distributed "AS-IS" AND WITHOUT ANY WARRANTY OF ANY KIND,
# INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY,
# NON-INFRINGEMENT, OR FITNESS FOR A PARTICULAR PURPOSE. See
# the AFFERO GNU General Public License for the complete license terms.
#
# You should have received a copy of the AFFERO GNU General Public License
# along with SciDB.  If not, see <http://www.gnu.org/licenses/agpl-3.0.html>
#
# END_COPYRIGHT
#

# Various functions that support S3 methods for the SciDB class

# cheeky solve
solve.scidb = function(a, b, ...)
{
  A = scidbeval(crossprod(a))
  s = svd(A)
  x = scidbeval(t(t(b) %*% a))
  x = t(s$u) %*% x
  x = s$d^(-1) * x
  x = s$v %*% x
  scidbeval(x)
}

cbind.scidb = function(x)
{
  if(length(dim(x))!=1) return(x)
  newdim=make.unique_(c(dimensions(x),x@attributes), "j")
  nd = sprintf("%s[%s,%s=0:0,1,0]",build_attr_schema(x) , build_dim_schema(x,bracket=FALSE),newdim)
  redimension(x, nd)
}

log.scidb = function(x, base=exp(1))
{
  log_scidb(x,base) 
}

colnames.scidb = function(x)
{
  NULL
}

`colnames<-.scidb` = function(x, value)
{
  stop("SciDB arrays don't support dimension labels")
}

rownames.scidb = function(x)
{
  NULL
}

`rownames<-.scidb` = function(x, value)
{
  stop("SciDB arrays don't support dimension labels")
}

names.scidb = function(x)
{
  NULL
}

`names<-.scidb` = function(x, value)
{
  stop("SciDB arrays don't support dimension labels")
}

dimnames.scidb = function(x)
{
  NULL
}

`dimnames<-.scidb` = function(x, value)
{
  stop("SciDB arrays don't support dimension labels")
}

summary.scidb = function(x)
{
  warning("Not available.")
  invisible()
}

`[<-.scidb` = function(x, ..., value)
{
  m = match.call()
  a = scidb_attributes(x)[1]
  if(!is.null(m$attr)) a = m$attr
  ai = which(scidb_attributes(x) %in% a)
  i = list(...)
  if(!all(unlist(lapply(i,checkseq)))) stop("Assignment is limited to contiguous blocks for now.")
  d = sapply(i, length) # dimensions
  s = sapply(i, function(u) u[1]) # origin
  if(is.scidb(value))
  {
    y = translate(value,s, newstart=scidb_coordinate_start(x), newchunk=scidb_coordinate_chunksize(x))
    ans = merge(x, y, by.x=dimensions(x), by.y=dimensions(y),merge=TRUE)@name
    ans = sprintf("store(%s,%s)",ans,x@name)
    iquery(ans)
    return(x)
  } else
  {
# Note, ordered by rows thanks to aperm
    if(!is.array(value)) value = array(value)
    v = as.scidb(as.vector(aperm(value)), nullable=scidb_nullable(x)[ai], attr=a, reshape=FALSE)
    reschema = sprintf("%s%s", build_attr_schema(v),
              build_dim_schema(x, newstart=s, newlen=d))
    ans = merge(x, redimension(reshape(v, schema=reschema), schema=schema(x)), merge=TRUE)
    ans = sprintf("store(%s,%s)",ans,x@name)
    iquery(ans)
  }
  x
}

# Array subsetting wrapper.
# x: A Scidb array object
# ...: list of dimensions
# 
# Returns a materialized R array if length(list(...))==0.
# Or, a scidb array promise.
`[.scidb` = function(x, ...)
{
  M = match.call()
  if(is.null(M$drop)) drop=TRUE  # if TRUE follow R drop convention
  else drop=M$drop
  if(is.null(M$eval)) eval=FALSE  # if TRUE eval (not really needed anymore)
  else eval=M$eval
  if(is.null(M$redim)) redim=TRUE  # if FALSE don't reset coordinates
  else redim=M$redim
# inverse of redim (same functionality) for user convenience
  if(!is.null(M$between)) redim=!M$between
  if(!is.null(M$redim) && !is.null(M$between))
  {
    warning("The `redim` and `between` options are antonyms but they provide the same control over the query. When both are specified the `redim` option is ignored and subsetting only pays attention to the between option.")
  }
  M = M[3:length(M)]
  if(!is.null(names(M))) M = M[!(names(M) %in% c("drop","eval","redim","between"))]
# i shall contain a list of requested index values
  E = parent.frame()
  i = lapply(1:length(M), function(j) tryCatch(eval(M[j][[1]],E),error=function(e)c()))
# User wants this materialized to R...
  if(all(sapply(i,is.null)))
    return(materialize(x,drop=drop))
# Not materializing, return a SciDB array
  if(length(i)!=length(dim(x))) stop("Dimension mismatch")
  dimfilter(x,i,eval,drop=drop,redim)
}

`dim<-.scidb` = function(x, value)
{
  reshape(x, shape=value)
}

str.scidb = function(object, ...)
{
  .scidbstr(object)
}

print.scidb = function(x, ...)
{
  cat("\nSciDB array ",x@name)
  cat("\n")
  print(head(x))
  if(is.null(dim(x))) j = as.numeric(scidb_coordinate_bounds(x)$length) - 6
  else j = dim(x)[1]-6
  if(j>2) cat("and ",j,"more rows not displayed...\n")
  if(length(dim(x))>0) {
    k = dim(x)[2] - 6
    if(k>2) cat("and ",k,"more columns not displayed...\n")
  }
}

ncol.scidb = function(x) dim(x)[2]
nrow.scidb = function(x) dim(x)[1]
dim.scidb = function(x) as.numeric(scidb_coordinate_bounds(x)$length)
length.scidb = function(x) prod(as.numeric(scidb_coordinate_bounds(x)$length))

# Vector, Matrix, matrix, or data.frame only.
# XXX Future: Add n-d array support here (TODO)
as.scidb = function(X,
                    name=tmpnam(),
                    chunksize,
                    overlap,
                    start,
                    chunkSize = chunksize,
                    gc=TRUE, ...)
{
  if(inherits(X,"raw"))
  {
    return(raw2scidb(X,name=name,gc=gc,...))
  }
  if(inherits(X,"data.frame"))
  {
    if(missing(chunksize))
      return(df2scidb(X,name=name,gc=gc,start=start,...))
    else
      return(df2scidb(X,name=name,chunkSize=as.numeric(chunksize[[1]]),gc=gc,start=start,...))
  }
  if(typeof(X) == "S4") type = .scidbtypes[[typeof(X@x)]]
  else type = .scidbtypes[[typeof(X)]]
  if(is.null(type)) {
    stop(paste("Unupported data type. The package presently supports: ",
       paste(.scidbtypes,collapse=" "),".",sep=""))
   }
  force_type = type
  if(is.factor(X))
  {
    if("scidb_factor" %in% class(X))
    {
      levels(X) = levels_scidb(X)
      X = as.integer(as.vector(X))  # XXX !!! XXX THIS LIMITS INDEX VALUES TO 31 bits!!! !!!
      force_type = "int64"
    }
    else
      X = as.vector(X)
  }
# Check for a bunch of optional hidden arguments
  args = list(...)
  attr_name = "val"
  flip = FALSE
  if(!is.null(args$dimension))  # flip attribute and dimension
  {
    force_type = "int64"
    flip = TRUE
    attr_name = "i"
  }
  nullable = TRUE
  if(!is.null(args$nullable)) nullable = as.logical(args$nullable) # control nullability
  if(!is.null(args$attr)) attr_name = as.character(args$attr)      # attribute name
  do_reshape = TRUE
  nd_reshape = NULL
  if(!is.null(args$reshape)) do_reshape = as.logical(args$reshape) # control reshape
  if(!is.null(args$type)) force_type = as.character(args$type) # limited type conversion
  if(missing(chunksize))
  {
# Note nrow, ncol might be NULL here if X is not a matrix. That's OK, we'll
# deal with that case later.
    chunkSize=c(min(1000L,nrow(X)),min(1000L,ncol(X)))
  }
  chunkSize = as.numeric(chunkSize)
  if(length(chunkSize)==1) chunkSize = c(chunkSize, chunkSize)
  if(!missing(overlap)) warning("Sorry, overlap is not yet supported by the as.scidb function. Consider using the reparition function for now.")
  overlap = c(0,0)
  if(missing(start)) start=c(0,0)
  start     = as.numeric(start)
  if(length(start)==1) start=c(start,start)
  if(inherits(X,"dgCMatrix"))
  {
# Sparse matrix case
    return(.Matrix2scidb(X,name=name,rowChunkSize=chunkSize[[1]],colChunkSize=chunkSize[[2]],start=start,gc=gc,...))
  }
  D = dim(X)
  start = as.integer(start)
  overlap = as.integer(overlap)
  dimname = make.unique_(attr_name,"i")
  if(is.null(D)) {
# X is a vector
    if(!is.vector(X)) stop ("X must be a matrix or a vector")
    do_reshape = FALSE
    chunkSize = min(chunkSize[[1]],length(X))
    X = as.matrix(X)
    schema = sprintf(
        "< %s : %s null>  [%s=%.0f:%.0f,%.0f,%.0f]", attr_name, force_type, dimname, start[[1]],
        nrow(X)-1+start[[1]], min(nrow(X),chunkSize), overlap[[1]])
    load_schema = schema
  } else if(length(D)>2)
  {
    nd_reshape = dim(X)
    do_reshape = FALSE
    X = as.matrix(as.vector(aperm(X)))
    schema = sprintf(
        "< %s : %s null>  [%s=%.0f:%.0f,%.0f,%.0f]", attr_name, force_type, dimname, start[[1]],
        nrow(X)-1+start[[1]], min(nrow(X),chunkSize), overlap[[1]])
    load_schema = sprintf("<%s:%s null>[__row=1:%.0f,1000000,0]",attr_name, force_type,  length(X))
  } else {
# X is a matrix
    schema = sprintf(
      "< %s : %s  null>  [i=%.0f:%.0f,%.0f,%.0f, j=%.0f:%.0f,%.0f,%.0f]", attr_name, force_type, start[[1]],
      nrow(X)-1+start[[1]], chunkSize[[1]], overlap[[1]], start[[2]], ncol(X)-1+start[[2]],
      chunkSize[[2]], overlap[[2]])
    load_schema = sprintf("<%s:%s null>[__row=1:%.0f,1000000,0]",attr_name, force_type,  length(X))
  }
  if(!is.matrix(X)) stop ("X must be a matrix or a vector")

  DEBUG = FALSE
  if(!is.null(options("scidb.debug")[[1]]) && TRUE==options("scidb.debug")[[1]]) DEBUG=TRUE
  td1 = proc.time()
# Obtain a session from shim for the upload process
  session = getSession()
  on.exit( GET("/release_session", list(id=session), err=FALSE) ,add=TRUE)

# Upload the data
  bytes = .Call("scidb_raw", as.vector(t(X)), PACKAGE="scidb")
  ans = POST(bytes, list(id=session))
  ans = gsub("\n", "", gsub("\r", "", ans))
  if(DEBUG)
  {
    cat("Data upload time",(proc.time()-td1)[3],"\n")
  }

# Load query
  if(!is.null(nd_reshape))
  {
    return(scidbeval(reshape_scidb(scidb(sprintf("input(%s,'%s', 0, '(%s null)')",load_schema,ans,type)), shape=nd_reshape),name=name))
  }
  if(do_reshape)
  {
    query = sprintf("store(reshape(input(%s,'%s', -2, '(%s null)'),%s),%s)",load_schema,ans,type,schema,name)
  }
  else
  {
    if(flip)
    {
      schema = sprintf(
        "< %s : int64>  [%s=%.0f:*,%.0f,%.0f]", dimname, attr_name, start[[1]],
         min(nrow(X),chunkSize), overlap[[1]])
      query = sprintf("store(redimension(input(%s,'%s', -2, '(%s null)'),%s),%s)",load_schema,ans,type,schema,name)
    } else
    {
      query = sprintf("store(input(%s,'%s', -2, '(%s null)'),%s)",load_schema,ans,type,name)
    }
  }
  iquery(query)
  ans = scidb(name,gc=gc)
  if(!nullable) ans = replaceNA(ans)
  ans
}
