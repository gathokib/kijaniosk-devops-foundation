# Region and Availability Zones

## Recommended Architecture

KijaniKiosk should be deployed in an AWS Region with multiple Availability Zones (AZs).

An AWS Region is a separate geographic area that contains multiple isolated Availability Zones. Availability Zones are separate locations within a Region designed to provide isolation from failures in other zones.

## Multi-AZ Design

The application should be distributed across at least two Availability Zones.

- The application can run across multiple AZs to improve availability.
- The database should use a highly available configuration across AZs where supported.
- If one Availability Zone becomes unavailable, services in another AZ can continue operating.
- This reduces the risk of a single point of failure.

## Why This Matters

Using multiple Availability Zones improves reliability and availability. It also allows the system to continue serving users during failures or maintenance affecting one Availability Zone.

The architecture should keep related resources within the same AWS Region to reduce unnecessary latency while using multiple AZs for resilience.
