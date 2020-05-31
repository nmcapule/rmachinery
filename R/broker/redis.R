library(redux)
library(jsonlite)
library(uuid)

brokerInit <- function(brokerURI) {
    broker <- redux::hiredis(url=brokerURI)
    return(broker)
}

brokerSendTask <- function(broker, queue, task) {
    broker$RPUSH(queue, jsonlite::toJSON(task, auto_unbox=TRUE))
}

brokerSendSimpleTask <- function(broker, queue, name, args=list()) {
    json <- sprintf('{
        "UUID":"task_%s",
        "Name":"%s",
        "RoutingKey":"%s",
        "ETA":null,
        "GroupUUID":"",
        "GroupTaskCount":0,
        "Args": %s,
        "Headers": {},
        "Priority":0,
        "Immutable":false,
        "RetryCount":0,
        "RetryTimeout":0,
        "OnSuccess":null,
        "OnError":null,
        "BrokerMessageGroupId":"",
        "SQSReceiptHandle":"",
        "StopTaskDeletionOnError":false,
        "IgnoreWhenTaskNotRegistered":false
    }',
        uuid::UUIDgenerate(),
        name,
        queue,
        jsonlite::toJSON(args, auto_unbox=TRUE)
    )

    broker$RPUSH(queue, json)

    return(jsonlite::fromJSON(json))
}

brokerReceiveTask <- function(broker, queue, timeout=0) {
    response <- broker$BLPOP(queue, timeout)
    Sys.sleep(0.01) # needed for R to notice that interrupt has happened
    if (is.null(response)) {
        return(NULL)
    }
    return(jsonlite::fromJSON(response[[2]]))
}
