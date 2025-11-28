import { AnalyticsSummary, ReportStatus } from "../../pkg/types";

export interface AnalyticsOverviewResponse {
  summary: AnalyticsSummary;
}

export interface ReportGenerationResponse {
  reportId: string;
  status: ReportStatus;
}

