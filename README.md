# From Always-On to On-Demand: Optimize Kubernetes Costs in Non-Production Environments

Most tech companies maintain a non-production environment for customers to integrate with their products via provided APIs. These environments are typically used during business hours on weekdays. Depending on the industry, they may go unused for days if there are no new customers integrating.

In addition to customer-facing environments, companies also maintain internal development environments. These are used by developers and QA teams to test and validate new features, perform load testing, and conduct other quality assurance tasks. Like the external non-production environments, these internal systems are usually active during business hours and may remain idle during off-hours or when not in use.

The goal of this material is to present a commonly used approach to reduce costs associated with idle environments running inside Kubernetes, and to explore ways to create optimized, on-demand environments.

## Scheduled Startup and Shutdown

A common and effective approach is to use Kubernetes CronJobs to schedule the startup and shutdown of applications during business hours on weekdays. This ensures that environments are only active when needed, reducing unnecessary resource usage.

It's important to note, however, that shutting down applications is only cost-effective when the worker nodes are configured with autoscaling. For example, in AWS EKS, solutions like Karpenter and Cluster Autoscaler can automatically scale down nodes when no workloads are running.

Let us take a closer look at how to set up a scheduled job that turns all applications on and off, excluding only the core components necessary for Kubernetes operation.