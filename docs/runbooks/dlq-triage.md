# Runbook: dead-letter queue is not empty

**What it means:** a lab job was received three times and never deleted, so SQS moved it to the DLQ. The
CloudWatch alarm `...-lab-jobs-dlq-not-empty` emails. (An idle queue's metrics can lag, so the email may arrive
several minutes late.)

## 1. Look at the message

```bash
DLQ=$(aws sqs get-queue-url --queue-name cloud-lab-platform-dev-lab-jobs-dlq --query QueueUrl --output text)
aws sqs get-queue-attributes --queue-url $DLQ --attribute-names ApproximateNumberOfMessages
aws sqs receive-message --queue-url $DLQ --max-number-of-messages 5 --visibility-timeout 30 --attribute-names All
```

## 2. Find out why it failed

```bash
aws logs tail /ecs/cloud-lab-platform-dev/lab-worker --since 2h --format short | grep job_failed
```

Each `job_failed` line carries the `message_id` and `receive_count`. Decide:

| Cause | Action |
|---|---|
| **Poison message** (bad payload, the `poison-test` lab type used for demos) | Delete it; it will never succeed |
| **Transient failure** (a dependency was down) | Fix the cause, then redrive |
| **Worker bug** | Fix and deploy, then redrive |

## 3. Redrive or delete

```bash
# Move messages back to the source queue
aws sqs start-message-move-task \
  --source-arn arn:aws:sqs:us-east-1:<ACCOUNT_ID>:cloud-lab-platform-dev-lab-jobs-dlq \
  --destination-arn arn:aws:sqs:us-east-1:<ACCOUNT_ID>:cloud-lab-platform-dev-lab-jobs

# Or discard
aws sqs purge-queue --queue-url $DLQ
```

## 4. Clean up the record

The API creates the DynamoDB record as `PENDING` and the worker only advances it on success, so a record whose
job died stays `PENDING`. There is no terminal `FAILED` state yet (known gap). Check the table for orphaned
`PENDING` records and update or remove them by hand.

## Prevent a repeat

Retries are intentional (visibility timeout 60 s, three receives). If failures are common, alert earlier on the
`job_failed` log rate rather than waiting for the DLQ.
