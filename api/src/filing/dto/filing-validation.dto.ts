export interface ValidationCheck {
  field: string;
  label: string;
  passed: boolean;
  value?: string;
  severity: 'error' | 'warning';
}

export interface FilingValidationResult {
  ready: boolean;
  checks: ValidationCheck[];
}
