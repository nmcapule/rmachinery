ensure <- function(pkgname) {
    if (!require(pkgname, character.only=TRUE)) {
        install.packages(pkgname, repos="http://cran.us.r-project.org", dep=TRUE)
    }
}
# Requires libhiredis-dev (sudo apt install libhiredis-dev)
ensure("redux")
ensure("mongolite")
ensure("urltools")
ensure("jsonlite")
ensure("uuid")
