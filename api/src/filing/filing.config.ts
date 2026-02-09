export const filingConfig = {
  useMock: process.env.FILING_USE_MOCK !== 'false', // default true; set env to "false" to use real API
  leidosVendorUser: process.env.LEIDOS_VENDOR_USER || '',
  leidosVendorPass: process.env.LEIDOS_VENDOR_PASS || '',
  leidosBaseUrl:
    process.env.LEIDOS_BASE_URL || 'https://lmfsweb.afss.com/Website/rest',
};
