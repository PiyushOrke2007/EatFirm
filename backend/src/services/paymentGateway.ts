/**
 * Payment Gateway Abstraction & Future Gateway Boundary (SRS PAY-06).
 *
 * Defines the contract for future online payment aggregators (e.g., Razorpay, Stripe, Cashfree, UPI Intent).
 * Release 1.0 utilizes the CashOnDeliveryAdapter.
 *
 * NOTE: Online payment providers are not considered integrated until credentials,
 * webhooks, signing keys, and automated reconciliation tests exist.
 * Never store raw credit card numbers or CVV codes (PCI-DSS compliance).
 */

export interface PaymentIntentOptions {
  orderId: string;
  amountPaise: number;
  currency: string;
  customer: {
    id: string;
    name: string;
    email?: string;
    phone: string;
  };
  notes?: Record<string, string>;
}

export interface PaymentIntentResult {
  intentId: string;
  provider: 'COD' | 'RAZORPAY' | 'STRIPE';
  status: 'PENDING' | 'REQUIRES_PAYMENT' | 'SUCCEEDED' | 'FAILED';
  amountPaise: number;
  currency: string;
  clientSecret?: string;
  paymentUrl?: string;
}

export interface PaymentVerificationOptions {
  orderId: string;
  paymentId: string;
  providerReference?: string;
  signature?: string;
}

export interface PaymentVerificationResult {
  verified: boolean;
  paymentId: string;
  status: 'PAID' | 'FAILED';
  collectedAt?: Date;
  reference?: string;
  failureReason?: string;
}

/**
 * Universal interface for payment adapters.
 */
export interface PaymentGatewayAdapter {
  readonly providerName: string;

  /**
   * Initializes a payment intent/order before checkout completion.
   */
  createPaymentIntent(options: PaymentIntentOptions): Promise<PaymentIntentResult>;

  /**
   * Verifies payment outcome upon webhook or callback receipt.
   */
  verifyPayment(options: PaymentVerificationOptions): Promise<PaymentVerificationResult>;
}

/**
 * Release 1.0 Cash on Delivery Adapter.
 * Cash is collected at customer doorstep upon delivery.
 */
export class CashOnDeliveryAdapter implements PaymentGatewayAdapter {
  readonly providerName = 'COD';

  async createPaymentIntent(options: PaymentIntentOptions): Promise<PaymentIntentResult> {
    return {
      intentId: `cod_${options.orderId}`,
      provider: 'COD',
      status: 'PENDING',
      amountPaise: options.amountPaise,
      currency: options.currency,
    };
  }

  async verifyPayment(options: PaymentVerificationOptions): Promise<PaymentVerificationResult> {
    return {
      verified: true,
      paymentId: options.paymentId,
      status: 'PAID',
      collectedAt: new Date(),
      reference: options.providerReference || `COD_RECEIPT_${Date.now()}`,
    };
  }
}

export const defaultPaymentAdapter = new CashOnDeliveryAdapter();

/**
 * Boundary adapter for future online gateways (Razorpay/Stripe).
 * Strictly enforces that online gateway cannot be invoked in Release 1.0.
 */
export class MockOnlinePaymentGatewayAdapter implements PaymentGatewayAdapter {
  readonly providerName: string;

  constructor(providerName = 'ONLINE_GATEWAY') {
    this.providerName = providerName;
  }

  async createPaymentIntent(_options: PaymentIntentOptions): Promise<PaymentIntentResult> {
    throw new Error('Online payment gateways are disabled in Release 1.0 until credentials and webhooks are configured');
  }

  async verifyPayment(_options: PaymentVerificationOptions): Promise<PaymentVerificationResult> {
    throw new Error('Online payment gateways are disabled in Release 1.0 until credentials and webhooks are configured');
  }
}

