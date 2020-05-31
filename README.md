# Machinery R SDK

This is a subset R implementation of a worker for `RichardKnop/machinery`.

The package was created using this guide:
https://tinyheero.github.io/jekyll/update/2015/07/26/making-your-first-R-package.html

## Limitations

- Broker is strictly only for Redis
- BackendResult is strictly only for MongoDB

## Development Environment

Need to install the following packages:

```R
install.packages("redux", repos="http://cran.us.r-project.org")
install.packages("mongolite", repos="http://cran.us.r-project.org")
install.packages("urltools", repos="http://cran.us.r-project.org")
install.packages("jsonlite", repos="http://cran.us.r-project.org")
install.packages("uuid", repos="http://cran.us.r-project.org")
```

## Usage

To create a machinery instance and handle a task:

```R
machinery <- machineryInit(
    brokerURI="redis://:helloworld@localhost:6379",
    backendURI="mongodb://mongo:moonbucks@localhost:27017/?authSource=admin",
    queue="machinery_tasks"
)
# Note that the inputs / ouputs of a task handler must be data frames.
printHandler <- function(args) {
    print(args)
    args
}
machinery <- machineryRegisterTask(machinery, "print", printHandler)
machineryStart(machinery)
```

To send a task and wait for results:

```R
task <- machinerySendSimpleTask(machinery, "my-queue", "add", args)
results <- machineryWaitForResults(machinery, task)
```
