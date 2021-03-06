\name{translate.dcf}
\alias{translate.dcf}
\title{Read a DCF file into an R list.}
\usage{
translate.dcf(filename)
}
\arguments{
  \item{filename}{A character vector specifying the DCF
  file to be translated.}
}
\value{
Returns a list containing the entries from the DCF file.
}
\description{
This function will read a DCF file and translate the resulting
data frame into a list. The DCF format is used throughout ProjectTemplate
for configuration settings and ad hoc file format specifications.
}
\examples{
library('ProjectTemplate')

\dontrun{translate.dcf(file.path('config', 'global.dcf'))}
}

