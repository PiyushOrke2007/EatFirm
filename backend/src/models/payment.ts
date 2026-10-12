export type PaymentMethod = 'CASH_ON_DELIVERY' | 'UPI' | 'NET_BANKING' | 'CARD';
export type PaymentStatus = 'PENDING' | 'PAID' | 'FAILED' | 'REFUNDED';

export interface PaymentRecord {
  id: string;
  orderId: string;
  paymentMethod: PaymentMethod;
  paymentStatus: PaymentStatus;
  amount: string;
  currency: string;
  collectedAt: Date | null;
  collectedByUserId: string | null;
  transactionReference: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface PaymentEventRecord {
  id: string;
  paymentId: string;
  fromStatus: string | null;
  toStatus: string;
  actorUserId: string | null;
  actorRole: string | null;
  transactionReference: string | null;
  note: string | null;
  createdAt: Date;
}

export interface InvoiceRecord {
  id: string;
  orderId: string;
  invoiceNumber: string;
  customerId: string;
  restaurantId: string;
  issuedAt: Date;
  subtotal: string;
  deliveryFee: string;
  taxAmount: string;
  discountAmount: string;
  totalAmount: string;
  currency: string;
  paymentMethod: PaymentMethod;
  paymentStatus: PaymentStatus;
  recipientName: string;
  recipientPhone: string;
  deliveryAddress: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface InvoiceItemDetail {
  id: string;
  name: string;
  description: string | null;
  unitPrice: string;
  isVeg: boolean;
  quantity: number;
  lineTotal: string;
  itemInstructions: string | null;
}

export interface InvoiceDetailResponse {
  invoice: InvoiceRecord;
  order: {
    id: string;
    publicOrderNumber: string;
    createdAt: Date;
    fulfillmentStatus: string;
  };
  restaurant: {
    id: string;
    name: string;
    address: string;
    phone: string;
    cuisineType: string;
    foodLicenseNumber: string;
  };
  customer: {
    name: string;
    phone: string;
    deliveryAddress: string;
  };
  items: InvoiceItemDetail[];
  breakdown: {
    subtotal: string;
    deliveryFee: string;
    taxAmount: string;
    discountAmount: string;
    totalAmount: string;
    currency: string;
  };
  payment: {
    method: PaymentMethod;
    status: PaymentStatus;
    collectedAt: Date | null;
    transactionReference: string | null;
  };
}

