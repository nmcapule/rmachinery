% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/machinery.R
\name{machineryInit}
\alias{machineryInit}
\title{Creates a machinery interface.}
\usage{
machineryInit(brokerURI, backendURI, queue = DEFAULT_QUEUE)
}
\arguments{
\item{brokerURI}{Redis connection string}

\item{backendURI}{MongoDB connection string}

\item{queue}{Queue to get tasks from}
}
\value{
An object-like list implementing a machinery interface.
}
\description{
This function creates a machinery interface when given broker and backend
URLs. The broker can only be Redis, and the backend can only be MongoDB.
}
