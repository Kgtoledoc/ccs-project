# Workflows Module - Step Functions for Emergency and Business Processes

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ========================================
# STEP FUNCTION - EMERGENCY WORKFLOW
# ========================================
# NOTE: Step Functions commented out due to logging permissions issue
# resource "aws_sfn_state_machine" "emergency" {
#   name     = "${local.name_prefix}-emergency-workflow"
#   role_arn = var.step_functions_role_arn
# 
#   definition = jsonencode({
#     Comment = "Emergency Response Workflow - SLA <2 seconds"
#     StartAt = "RecordIncident"
#     States = {
#       RecordIncident = {
#         Type     = "Task"
#         Resource = "arn:aws:states:::dynamodb:putItem"
#         Parameters = {
#           TableName = var.dynamodb_incidents_table_name
#           Item = {
#             incident_id = {
#               "S.$" = "States.Format('INC-{}-{}', $.vehicleId, $.eventTimestamp)"
#             }
#             timestamp = {
#               "N.$" = "States.Format('{}', $.eventTimestamp)"
#             }
#             vehicle_id = {
#               "S.$" = "$.vehicleId"
#             }
#             type = {
#               "S.$" = "$.type"
#             }
#             severity = {
#               "S.$" = "$.severity"
#             }
#             status = {
#               S = "open"
#             }
#             location = {
#               M = {
#                 lat = {
#                   "N.$" = "States.Format('{}', $.location.lat)"
#                 }
#                 lon = {
#                   "N.$" = "States.Format('{}', $.location.lon)"
#                 }
#               }
#             }
#             created_at = {
#               "S.$" = "$$.State.EnteredTime"
#             }
#           }
#         }
#         ResultPath = "$.incidentRecord"
#         Next       = "DetermineResponseType"
#         Retry = [{
#           ErrorEquals     = ["States.ALL"]
#           IntervalSeconds = 1
#           MaxAttempts     = 3
#           BackoffRate     = 1.5
#         }]
#         Catch = [{
#           ErrorEquals = ["States.ALL"]
#           Next        = "RecordFailure"
#           ResultPath  = "$.error"
#         }]
#       }
# 
#       DetermineResponseType = {
#         Type = "Choice"
#         Choices = [
#           {
#             Variable      = "$.type"
#             StringEquals  = "panic_button"
#             Next          = "HighPriorityResponse"
#           },
#           {
#             Variable      = "$.type"
#             StringEquals  = "accident"
#             Next          = "HighPriorityResponse"
#           },
#           {
#             Variable      = "$.type"
#             StringEquals  = "hijack"
#             Next          = "HighPriorityResponse"
#           }
#         ]
#         Default = "StandardResponse"
#       }
# 
#       HighPriorityResponse = {
#         Type = "Parallel"
#         Branches = [
#           {
#             StartAt = "NotifyAuthorities"
#             States = {
#               NotifyAuthorities = {
#                 Type     = "Task"
#                 Resource = "arn:aws:states:::sns:publish"
#                 Parameters = {
#                   TopicArn = var.sns_authorities_topic_arn
#                   Subject  = "🚨 EMERGENCY ALERT - Immediate Response Required"
#                   Message = {
#                     default = "Emergency detected"
#                     sms = "EMERGENCY: Vehicle $.vehicleId - $.type at location $.location"
#                     email = jsonencode({
#                       incident_type = "$.type"
#                       vehicle_id    = "$.vehicleId"
#                       location      = "$.location"
#                       timestamp     = "$.eventTimestamp"
#                       severity      = "CRITICAL"
#                       action        = "Immediate dispatch required"
#                     })
#                   }
#                   MessageAttributes = {
#                     priority = {
#                       DataType    = "String"
#                       StringValue = "CRITICAL"
#                     }
#                     incident_type = {
#                       DataType    = "String"
#                       "StringValue.$" = "$.type"
#                     }
#                   }
#                 }
#                 ResultPath = "$.authoritiesNotification"
#                 End        = true
#                 Retry = [{
#                   ErrorEquals     = ["States.ALL"]
#                   IntervalSeconds = 1
#                   MaxAttempts     = 2
#                   BackoffRate     = 1.0
#                 }]
#               }
#             }
#           },
#           {
#             StartAt = "NotifyOwner"
#             States = {
#               NotifyOwner = {
#                 Type     = "Task"
#                 Resource = "arn:aws:states:::sns:publish"
#                 Parameters = {
#                   TopicArn = var.sns_owner_topic_arn
#                   Subject  = "Emergency Alert - Your Vehicle"
#                   Message = {
#                     default = "Emergency detected on your vehicle"
#                     sms = "ALERT: Your vehicle $.vehicleId has triggered an emergency: $.type"
#                     email = jsonencode({
#                       vehicle_id = "$.vehicleId"
#                       incident   = "$.type"
#                       location   = "$.location"
#                       timestamp  = "$.eventTimestamp"
#                       status     = "Authorities notified, help on the way"
#                     })
#                   }
#                 }
#                 ResultPath = "$.ownerNotification"
#                 End        = true
#               }
#             }
#           },
#           {
#             StartAt = "ActivateVideoRecording"
#             States = {
#               ActivateVideoRecording = {
#                 Type     = "Task"
#                 Resource = "arn:aws:states:::lambda:invoke"
#                 Parameters = {
#                   FunctionName = var.video_activation_lambda_arn
#                   Payload = {
#                     vehicle_id = "$.vehicleId"
#                     incident_id = "$.incidentRecord.incident_id"
#                     action      = "activate_continuous_recording"
#                     duration    = 3600
#                   }
#                 }
#                 ResultPath = "$.videoActivation"
#                 End        = true
#               }
#             }
#           }
#         ]
#         ResultPath = "$.parallelResults"
#         Next       = "UpdateIncidentStatus"
#       }
# 
#       StandardResponse = {
#         Type = "Parallel"
#         Branches = [
#           {
#             StartAt = "NotifyOwnerStandard"
#             States = {
#               NotifyOwnerStandard = {
#                 Type     = "Task"
#                 Resource = "arn:aws:states:::sns:publish"
#                 Parameters = {
#                   TopicArn = var.sns_owner_topic_arn
#                   Subject  = "Vehicle Alert"
#                   Message = {
#                     default = "Alert on your vehicle"
#                     email = jsonencode({
#                       vehicle_id = "$.vehicleId"
#                       alert_type = "$.type"
#                       location   = "$.location"
#                       timestamp  = "$.eventTimestamp"
#                     })
#                   }
#                 }
#                 ResultPath = "$.ownerNotification"
#                 End        = true
#               }
#             }
#           }
#         ]
#         ResultPath = "$.parallelResults"
#         Next       = "UpdateIncidentStatus"
#       }
# 
#       UpdateIncidentStatus = {
#         Type     = "Task"
#         Resource = "arn:aws:states:::dynamodb:updateItem"
#         Parameters = {
#           TableName = var.dynamodb_incidents_table_name
#           Key = {
#             incident_id = {
#               "S.$" = "$.incidentRecord.incident_id.S"
#             }
#             timestamp = {
#               "N.$" = "$.incidentRecord.timestamp.N"
#             }
#           }
#           UpdateExpression = "SET #status = :status, notifications_sent = :notifications, updated_at = :updated_at"
#           ExpressionAttributeNames = {
#             "#status" = "status"
#           }
#           ExpressionAttributeValues = {
#             ":status" = {
#               S = "notified"
#             }
#             ":notifications" = {
#               BOOL = true
#             }
#             ":updated_at" = {
#               "S.$" = "$$.State.EnteredTime"
#             }
#           }
#         }
#         ResultPath = "$.updateResult"
#         End        = true
#       }
# 
#       RecordFailure = {
#         Type     = "Task"
#         Resource = "arn:aws:states:::dynamodb:putItem"
#         Parameters = {
#           TableName = var.dynamodb_incidents_table_name
#           Item = {
#             incident_id = {
#               "S.$" = "States.Format('INC-FAILED-{}', $$.Execution.Name)"
#             }
#             timestamp = {
#               "N.$" = "States.Format('{}', $.eventTimestamp)"
#             }
#             status = {
#               S = "failed"
#             }
#             error = {
#               "S.$" = "$.error.Error"
#             }
#             error_cause = {
#               "S.$" = "$.error.Cause"
#             }
#           }
#         }
#         End = true
#       }
#     }
#   })
# 
#   logging_configuration {
#     log_destination        = "${aws_cloudwatch_log_group.emergency_workflow.arn}:*"
#     include_execution_data = true
#     level                  = "ALL"
#   }
# 
#   tracing_configuration {
#     enabled = true
#   }
# 
#   tags = merge(
#     var.tags,
#     {
#       Name = "${local.name_prefix}-emergency-workflow"
#       Type = "Emergency"
#       SLA  = "2s"
#     }
#   )
# }

# ========================================
# STEP FUNCTION - BUSINESS WORKFLOW (Sales)
# ========================================
# NOTE: Step Functions commented out due to logging permissions issue
# resource "aws_sfn_state_machine" "business" {
#   name     = "${local.name_prefix}-business-workflow"
#   role_arn = var.step_functions_role_arn
# 
#   definition = jsonencode({
#     Comment = "Business Process Workflow - Sales and Approvals"
#     StartAt = "ValidateCustomerData"
#     States = {
#       ValidateCustomerData = {
#         Type     = "Task"
#         Resource = "arn:aws:states:::lambda:invoke"
#         Parameters = {
#           FunctionName = var.validation_lambda_arn
#           Payload = {
#             customer_id   = "$.customer_id"
#             document_type = "$.document_type"
#             document_id   = "$.document_id"
#             company_info  = "$.company_info"
#           }
#         }
#         ResultPath = "$.validationResult"
#         Next       = "CheckValidationStatus"
#         Retry = [{
#           ErrorEquals     = ["States.TaskFailed"]
#           IntervalSeconds = 2
#           MaxAttempts     = 3
#           BackoffRate     = 2.0
#         }]
#         Catch = [{
#           ErrorEquals = ["States.ALL"]
#           Next        = "ValidationFailed"
#           ResultPath  = "$.error"
#         }]
#       }
# 
#       CheckValidationStatus = {
#         Type = "Choice"
#         Choices = [{
#           Variable     = "$.validationResult.Payload.valid"
#           BooleanEquals = true
#           Next         = "CheckContractSize"
#         }]
#         Default = "ValidationFailed"
#       }
# 
#       CheckContractSize = {
#         Type = "Choice"
#         Choices = [{
#           Variable      = "$.number_of_vehicles"
#           NumericLessThan = 50
#           Next          = "AutoApprove"
#         }]
#         Default = "RequireManagerApproval"
#       }
# 
#       AutoApprove = {
#         Type     = "Task"
#         Resource = "arn:aws:states:::lambda:invoke"
#         Parameters = {
#           FunctionName = var.contract_creation_lambda_arn
#           Payload = {
#             customer_id        = "$.customer_id"
#             number_of_vehicles = "$.number_of_vehicles"
#             contract_type      = "$.contract_type"
#             approval_type      = "automatic"
#             approved_by        = "system"
#           }
#         }
#         ResultPath = "$.contractResult"
#         Next       = "ProcessPayment"
#       }
# 
#       RequireManagerApproval = {
#         Type     = "Task"
#         Resource = "arn:aws:states:::sns:publish"
#         Parameters = {
#           TopicArn = var.sns_manager_topic_arn
#           Subject  = "Manager Approval Required - Large Contract"
#           Message = {
#             default = "Manager approval required"
#             email = jsonencode({
#               customer_id        = "$.customer_id"
#               number_of_vehicles = "$.number_of_vehicles"
#               estimated_value    = "$.estimated_value"
#               contract_details   = "$.contract_details"
#               approval_token     = "$.execution_id"
#             })
#           }
#         }
#         ResultPath = "$.notificationResult"
#         Next       = "WaitForApproval"
#       }
# 
#       WaitForApproval = {
#         Type    = "Task"
#         Resource = "arn:aws:states:::lambda:invoke.waitForTaskToken"
#         Parameters = {
#           FunctionName = var.approval_handler_lambda_arn
#           Payload = {
#             "task_token.$" = "$$.Task.Token"
#             execution_id = "$.execution_id"
#             customer_id  = "$.customer_id"
#             timeout      = 86400
#           }
#         }
#         TimeoutSeconds = 86400
#         ResultPath     = "$.approvalResult"
#         Next           = "CheckApprovalDecision"
#         Catch = [{
#           ErrorEquals = ["States.Timeout"]
#           Next        = "ApprovalTimeout"
#           ResultPath  = "$.error"
#         }]
#       }
# 
#       CheckApprovalDecision = {
#         Type = "Choice"
#         Choices = [{
#           Variable      = "$.approvalResult.Payload.approved"
#           BooleanEquals = true
#           Next          = "CreateApprovedContract"
#         }]
#         Default = "ApprovalRejected"
#       }
# 
#       CreateApprovedContract = {
#         Type     = "Task"
#         Resource = "arn:aws:states:::lambda:invoke"
#         Parameters = {
#           FunctionName = var.contract_creation_lambda_arn
#           Payload = {
#             customer_id        = "$.customer_id"
#             number_of_vehicles = "$.number_of_vehicles"
#             contract_type      = "$.contract_type"
#             approval_type      = "manual"
#             approved_by        = "$.approvalResult.Payload.manager_id"
#             approved_at        = "$.approvalResult.Payload.approved_at"
#           }
#         }
#         ResultPath = "$.contractResult"
#         Next       = "ProcessPayment"
#       }
# 
#       ProcessPayment = {
#         Type     = "Task"
#         Resource = "arn:aws:states:::lambda:invoke"
#         Parameters = {
#           FunctionName = var.payment_processing_lambda_arn
#           Payload = {
#             customer_id   = "$.customer_id"
#             contract_id   = "$.contractResult.Payload.contract_id"
#             amount        = "$.estimated_value"
#             payment_method = "$.payment_method"
#           }
#         }
#         ResultPath = "$.paymentResult"
#         Next       = "CheckPaymentStatus"
#         Retry = [{
#           ErrorEquals     = ["PaymentGatewayError"]
#           IntervalSeconds = 5
#           MaxAttempts     = 2
#           BackoffRate     = 1.5
#         }]
#         Catch = [{
#           ErrorEquals = ["States.ALL"]
#           Next        = "PaymentFailed"
#           ResultPath  = "$.error"
#         }]
#       }
# 
#       CheckPaymentStatus = {
#         Type = "Choice"
#         Choices = [{
#           Variable      = "$.paymentResult.Payload.status"
#           StringEquals  = "success"
#           Next          = "ActivateService"
#         }]
#         Default = "PaymentFailed"
#       }
# 
#       ActivateService = {
#         Type     = "Task"
#         Resource = "arn:aws:states:::lambda:invoke"
#         Parameters = {
#           FunctionName = var.service_activation_lambda_arn
#           Payload = {
#             customer_id = "$.customer_id"
#             contract_id = "$.contractResult.Payload.contract_id"
#             vehicles    = "$.vehicles"
#           }
#         }
#         ResultPath = "$.activationResult"
#         Next       = "SendWelcomeEmail"
#       }
# 
#       SendWelcomeEmail = {
#         Type     = "Task"
#         Resource = "arn:aws:states:::sns:publish"
#         Parameters = {
#           TopicArn = var.sns_owner_topic_arn
#           Subject  = "Welcome to CCS - Service Activated"
#           Message = {
#             default = "Your service has been activated"
#             email = jsonencode({
#               customer_id = "$.customer_id"
#               contract_id = "$.contractResult.Payload.contract_id"
#               message     = "Welcome to CCS! Your vehicle monitoring service is now active."
#             })
#           }
#         }
#         ResultPath = "$.welcomeEmailResult"
#         End        = true
#       }
# 
#       ValidationFailed = {
#         Type = "Fail"
#         Error = "ValidationError"
#         Cause = "Customer validation failed"
#       }
# 
#       ApprovalRejected = {
#         Type = "Fail"
#         Error = "ApprovalRejected"
#         Cause = "Manager rejected the contract"
#       }
# 
#       ApprovalTimeout = {
#         Type = "Fail"
#         Error = "ApprovalTimeout"
#         Cause = "Manager approval timed out after 24 hours"
#       }
# 
#       PaymentFailed = {
#         Type = "Fail"
#         Error = "PaymentError"
#         Cause = "Payment processing failed"
#       }
#     }
#   })
# 
#   logging_configuration {
#     log_destination        = "${aws_cloudwatch_log_group.business_workflow.arn}:*"
#     include_execution_data = true
#     level                  = "ERROR"
#   }
# 
#   tracing_configuration {
#     enabled = true
#   }
# 
#   tags = merge(
#     var.tags,
#     {
#       Name = "${local.name_prefix}-business-workflow"
#       Type = "Business"
#     }
#   )
# }
# 
# # ========================================
# # CLOUDWATCH LOG GROUPS
# # ========================================
# resource "aws_cloudwatch_log_group" "emergency_workflow" {
#   name              = "/aws/stepfunctions/${local.name_prefix}/emergency"
#   retention_in_days = var.log_retention_days
# 
#   kms_key_id = var.kms_key_id
# 
#   tags = merge(
#     var.tags,
#     {
#       Name = "${local.name_prefix}-emergency-workflow-logs"
#     }
#   )
# }
# 
# resource "aws_cloudwatch_log_group" "business_workflow" {
#   name              = "/aws/stepfunctions/${local.name_prefix}/business"
#   retention_in_days = var.log_retention_days
# 
#   kms_key_id = var.kms_key_id
# 
#   tags = merge(
#     var.tags,
#     {
#       Name = "${local.name_prefix}-business-workflow-logs"
#     }
#   )
# }
# 
# # ========================================
# # EVENTBRIDGE RULE - AUTO TRIGGER EMERGENCY WORKFLOW
# # ========================================
# resource "aws_cloudwatch_event_rule" "emergency_trigger" {
#   name        = "${local.name_prefix}-emergency-trigger"
#   description = "Auto-trigger emergency workflow from SQS events"
# 
#   event_pattern = jsonencode({
#     source      = ["aws.sqs"]
#     detail-type = ["AWS API Call via CloudTrail"]
#     detail = {
#       eventSource = ["sqs.amazonaws.com"]
#       eventName   = ["SendMessage"]
#       requestParameters = {
#         queueUrl = [var.emergency_queue_url]
#       }
#     }
#   })
# 
#   tags = merge(
#     var.tags,
#     {
#       Name = "${local.name_prefix}-emergency-trigger"
#     }
#   )
# }
# 
# resource "aws_cloudwatch_event_target" "emergency_trigger" {
#   rule      = aws_cloudwatch_event_rule.emergency_trigger.name
#   target_id = "EmergencyWorkflow"
#   arn       = aws_sfn_state_machine.emergency.arn
#   role_arn  = var.eventbridge_role_arn
# 
#   input_transformer {
#     input_paths = {
#       vehicleId = "$.detail.requestParameters.messageBody.vehicleId"
#       type      = "$.detail.requestParameters.messageBody.type"
#       timestamp = "$.detail.requestParameters.messageBody.timestamp"
#     }
#     input_template = "{\"vehicleId\": <vehicleId>, \"type\": <type>, \"eventTimestamp\": <timestamp>}"
#   }
# }

