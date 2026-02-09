export interface FilingResponse {
  success: boolean;
  filingStatus: string;
  filingReference?: string;
  filingVersionStamp?: string;
  filedAt?: string;
  message?: string;
  errors?: string[];
}
