# System Architecture

## Table of Contents

- [Overview](#overview)
- [Architecture Diagram](#architecture-diagram)
- [Component Details](#component-details)
- [Data Flow](#data-flow)
- [Security Architecture](#security-architecture)
- [Scalability & Performance](#scalability--performance)
- [Cost Optimization](#cost-optimization)

---

## Overview

The Video Compression Automation Pipeline is a serverless, event-driven architecture built on AWS that automatically processes video files uploaded to Google Drive. The system is designed for high availability, scalability, and cost-effectiveness.

### Design Principles

1. **Serverless-First**: Use managed services to minimize operational overhead
2. **Event-Driven**: React to events rather than polling
3. **Loosely Coupled**: Components communicate via events and APIs
4. **Stateless**: No persistent state in compute layers
5. **Pay-per-Use**: Only pay for resources when processing files

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          User Layer                                  │
│  ┌──────────────┐          ┌──────────────┐                         │
│  │ Google Drive │          │   Airtable   │                         │
│  │  (Upload)    │          │  (Metadata)  │                         │
│  └──────┬───────┘          └──────▲───────┘                         │
└─────────┼──────────────────────────┼──────────────────────────────┘
          │                          │
          │ Webhook                  │ API Calls
          ▼                          │
┌─────────────────────────────────────────────────────────────────────┐
│                     Orchestration Layer                              │
│  ┌──────────────────────────────────────────────┐                   │
│  │              n8n Cloud                       │                   │
│  │  ┌────────────────┐    ┌──────────────┐     │                   │
│  │  │ Google Drive   │───▶│ AWS Lambda   │     │                   │
│  │  │    Trigger     │    │     Node     │     │                   │
│  │  └────────────────┘    └──────────────┘     │                   │
│  └──────────────────────────────────────────────┘                   │
└─────────────────────────────┼──────────────────────────────────────┘
                              │
                              │ Invoke
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS Compute Layer                             │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                   AWS Lambda Functions                       │   │
│  │  ┌─────────────────────┐  ┌──────────────────────┐          │   │
│  │  │ video-file-processor│  │ completion-handler   │          │   │
│  │  │  • Download files   │  │  • Process results  │          │   │
│  │  │  • Upload to S3     │  │  • Calculate stats  │          │   │
│  │  │  • Submit MC jobs   │  │  • Move files       │          │   │
│  │  └──────────┬──────────┘  └──────────▲──────────┘          │   │
│  │             │                          │                     │   │
│  │             │                          │                     │   │
│  │             │              ┌───────────┴─────────┐           │   │
│  │             │              │  MetaDataLogger     │           │   │
│  │             │              │  • Log to Airtable │           │   │
│  │             │              └─────────────────────┘           │   │
│  └─────────────┼──────────────────────────────────────────────┘   │
└────────────────┼──────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS Processing Layer                              │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              AWS MediaConvert                                │   │
│  │  • H.264 encoding (QVBR)                                     │   │
│  │  • 720p minimum resolution                                   │   │
│  │  • Multi-pass high quality                                   │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      AWS Storage Layer                               │
│  ┌──────────────────────┐      ┌──────────────────────┐             │
│  │  S3 Temp Bucket      │      │ S3 Compressed Bucket │             │
│  │  • Temporary storage │      │ • Final storage      │             │
│  │  • Auto-delete 7d    │      │ • Long-term storage  │             │
│  └──────────────────────┘      └──────────────────────┘             │
└─────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   AWS Notification Layer                             │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │    Amazon SNS                                                │   │
│  │    • Email notifications                                     │   │
│  │    • Status updates                                          │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────
