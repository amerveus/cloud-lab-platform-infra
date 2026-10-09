# ADR-0004: API on EKS, queue worker on ECS Fargate Spot

**Status:** Accepted (Phases 1, 2, 4)

## Context
Two different workload shapes: an always-on API that needs HPA and a place to run Argo CD and Prometheus, and a
spiky, stateless queue consumer.

## Decision
The API runs on EKS. The worker runs on ECS Fargate with a Spot-weighted capacity strategy (4 Spot to 1
on-demand), scaled by step scaling on queue depth, with a warm minimum of one task.

## Consequences
- No nodes to manage for the worker. Spot is safe because an interrupted job's message was never deleted and
  reappears after the visibility timeout.
- Scale in only when visible plus in-flight messages is zero, so a task is never stopped mid-job.
- Two platforms to understand, justified by two different workload shapes.
- **Scale-from-zero did not work as designed.** SQS stops publishing metrics for idle queues, so the backlog
  alarm was blind and a job waited about 10 minutes. The floor is now one warm task (about 10 cents a day).

## Alternatives considered
- **Lambda for the worker:** cheaper at idle, but a 15-minute limit and a different packaging and deploy
  model. A good fit for short jobs; not chosen here.
- **KEDA on EKS:** polls the SQS API directly and would give true scale-to-zero; adds a controller to run.
- **Everything on EKS:** works, but gives up the no-nodes property for the bursty part.
