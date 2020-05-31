library(mongolite)
library(jsonlite)

backendInit <- function(backendURI) {
    backend <- list(url=backendURI)
    return(backend)
}

.backendGcms <- function(backend) {
    mongolite::mongo("group_metas", url=backend$url, db="machinery")
}

.backendTasks <- function(backend) {
    mongolite::mongo("tasks", url=backend$url, db="machinery")
}

backendSaveState <- function(backend, task, results=list(), error=NULL, state="PENDING") {
    errfield <- ""
    if (!is.null(error)) {
        errfield <- sprintf('"error": "%s",', gsub("\n", "", gsub('"', '', error)))
    }

    if (length(results) > 0) {
        names(results)[names(results) == "Name"] <- "name"
        names(results)[names(results) == "Type"] <- "type"
        names(results)[names(results) == "Value"] <- "value"
    }

    updates <- sprintf('{
        %s
        "results": %s,
        "task_name": "%s",
        "state": "%s"
    }',
        errfield,
        jsonlite::toJSON(results),
        task$Name,
        state
    )

    tasks <- .backendTasks(backend)
    tasks$update(
        sprintf('{"_id": "%s"}', task$UUID),
        sprintf('{
            "$set": %s
        }', updates),
        upsert=TRUE
    )
}

backendLoadResults <- function(backend, taskUUID) {
    tasks <- .backendTasks(backend)
    results <- tasks$find(sprintf('{"_id": "%s"}', taskUUID))
    if (is.null(results)) {
        return(NULL)
    }
    if (length(results) > 0) {
        names(results)[names(results) == "name"] <- "Name"
        names(results)[names(results) == "type"] <- "Type"
        names(results)[names(results) == "value"] <- "Value"
    }
    return(results[["results"]][[1]])
}

backendLoadGroupResults <- function(backend, groupUUID) {
    gcms <- .backendGcms(backend)
    resp <- gcms$find(sprintf('{"_id": "%s"}', groupUUID))
    if (is.null(resp)) {
        return(FALSE)
    }
    meta <- head(resp)

    taskUUIDs <- meta$task_uuids
    # TODO(nathaniel.capule): Implementation.
}

backendIsGroupCompleted <- function(backend, groupUUID) {
    # TODO(nathaniel.capule): Implementation.
    FALSE
}

backendUpdateGroupMeta <- function(backend, groupUUID, chordTriggered=NULL, lock=NULL) {
    # TODO(nathaniel.capule): Implementation.
    FALSE
}
