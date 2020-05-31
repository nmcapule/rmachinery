# source("./install.R", chdir=TRUE)
source("./R/broker/redis.R")
source("./R/backend/mongodb.R")

DEFAULT_QUEUE = "machinery_tasks"
DEFAULT_POLL_PERIOD = 3

#' Creates a machinery interface.
#' 
#' This function creates a machinery interface when given broker and backend
#' URLs. The broker can only be Redis, and the backend can only be MongoDB.
#' 
#' @param brokerURI Redis connection string
#' @param backendURI MongoDB connection string
#' @param queue Queue to get tasks from
#' @return An object-like list implementing a machinery interface.
#' @export
machineryInit <- function(brokerURI, backendURI, queue=DEFAULT_QUEUE) {
    list(
        working=TRUE,
        tasks=list(),
        broker=brokerInit(brokerURI),
        backend=backendInit(backendURI),
        queue=queue
    )
}

#' Sends a simple task to the given queue.
#' 
#' @param machinery The machinery instance to use
#' @param queue The target queue to send the task into
#' @param taskName The name of the task
#' @param args Argument given to the task. Data frame with column "Type" and "Value"
#' @return The created and sent task
#' @export
machinerySendSimpleTask <- function(machinery, queue, taskName, args=list()) {
    brokerSendSimpleTask(machinery$broker, queue, taskName, args)
}

#' Waits for result of the given task indefinitely.
#' 
#' This function is a blocking function.
#' 
#' @param machinery The machinery instance to use
#' @param task The machinery task to get the results from
#' @param pollSecs The number of seconds to rest before polling again
#' @return A data frame containing the results, with column "Type" and "Value"
#' @export
machineryWaitForResults <- function(machinery, task, pollSecs=DEFAULT_POLL_PERIOD) {
    while (machinery$working) {
        results <- backendLoadResults(machinery, task$UUID)
        if (is.null(results)) {
            Sys.sleep(pollSecs)
            continue
        }
        return(results)
    }
}

#' Registers a task handler for the given taskName.
#' 
#' @param machinery The machinery instance to use
#' @param taskName The name of the task that the handler handles
#' @param callback The callback function to invoke when machinery gets this task
#' @return The modified machinery instance
#' @export
machineryRegisterTask <- function(machinery, taskName, callback) {
    machinery$tasks[[taskName]] = callback
    machinery
}

.onTaskSuccess <- function(machinery, task, results) {
    backendSaveState(machinery$backend, task, results=results, state="SUCCESS")
    
    # Handler for when the task has a success callback.
    if (!is.null(task$OnSuccess)) {
        subtask <- task$OnSuccess
        queue <- subtask$RoutingKey
        if (queue == "") {
            queue = machinery$queue
        }
        backendSaveState(machinery$backend, subtask, state="PENDING")
        brokerSendTask(machiner$broker, queue, subtask)
    }

    # Handler for when then task is included in chords or groups (WIP).
    if (task$GroupUUID == "" | is.null(task$ChordCallback)) {
        return()
    }
    if (!backendIsGroupCompleted(machinery$backend, task$GroupUUID)) {
        return()
    }

    subtask <- task$ChordCallback
    subtask$Args <- backendLoadGroupResults(machinery$backend, task$GroupUUID)
    queue <- subtask$RoutingKey
    if (queue == "") {
        queue = machinery$queue
    }
    backendSaveState(machinery$backend, subtask, state="PENDING")
    backendUpdateGroupMeta(machinery$backend, task$GroupUUID, chordTriggered=TRUE)
    brokerSendTask(machinery$broker, queue, subtask)
}

.onTaskFailed <- function(machinery, task, error) {
    backendSaveState(machinery$backend, task, error=error, state="FAILED")

    if (!is.null(task$OnError)) {
        subtask <- task$OnError
        subtask$Args <- data.frame(
            data.frame(
                Name="error",
                Type="string",
                Value=error
            )
        )
        queue <- subtask$RoutingKey
        if (queue == "") {
            queue = machinery$queue
        }
        backendSaveState(machinery$backend, subtask, state="PENDING")
        brokerSendTask(machinery$broker, queue, subtask)
    }
}

#' Start consuming tasks for the given machinery instance.
#' 
#' This function is a blocking function.
#' 
#' @param machinery The machinery instance to use.
#' @param pollSecs The number of seconds to wait before polling again for new tasks.
#' @return None
#' @export
machineryStart <- function(machinery, pollSecs=DEFAULT_POLL_PERIOD) {
    print("Starting R worker...")

    while (machinery$working) {
        task <- brokerReceiveTask(machinery$broker, machinery$queue, pollSecs)
        if (is.null(task)) {
            next
        }

        # If received task is not in the list of tasks, requeue to broker.
        if (!(task$Name %in% names(machinery$tasks))) {
            print(paste("Unknown task", task$Name, "from queue", machinery$queue,"- sending back to queue."))
            Sys.sleep(pollSecs)
            brokerSendTask(machinery$broker, machinery$queue, task)
            next
        }

        print(paste("Got task: ", str(task$UUID)))

        # Do the work!
        callback <- machinery$tasks[[task$Name]]
        tryCatch(
            {
                results <- callback(task$Args)
                .onTaskSuccess(machinery, task, results)
            },
            error=function(error) {
                print(error)
                .onTaskFailed(machinery, task, error)
            }
        )
    }
}
