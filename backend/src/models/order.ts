export type OrderFulfillmentStatus =
  | 'PLACED'
  | 'CONFIRMED'
  | 'PREPARING'
  | 'OUT_FOR_DELIVERY'
  | 'DELIVERED'
  | 'CANCELLED';

export type OrderPaymentStatus = 'PENDING' | 'PAID' | 'REFUNDED' | 'FAILED';

export type OrderPaymentMethod = 'CASH_ON_DELIVERY';

export interface OrderItemModel {
  id: string;
  orderId: string;
  menuItemId: string | null;
  itemName: string;
  itemDescription: string | null;
  unitPrice: string;
  isVeg: boolean;
  quantity: number;
  lineTotal: string;
  itemInstructions: string | null;
  createdAt: string;
}

export interface OrderStatusEventModel {
  id: string;
  orderId: string;
  fromStatus: OrderFulfillmentStatus | null;
  toStatus: OrderFulfillmentStatus;
  actorUserId: string | null;
  actorRole: string | null;
  note: string | null;
  createdAt: string;
}

export interface OrderModel {
  id: string;
  publicOrderNumber: string;
  customerId: string;
  restaurantId: string;
  restaurantName?: string;
  restaurantAddress?: string;
  deliveryAddressSnapshot: string;
  customerPhoneSnapshot: string;
  customerNameSnapshot: string;
  specialInstructions: string | null;
  isScheduled: boolean;
  scheduledFor: string | null;
  subtotal: string;
  deliveryFee: string;
  taxAmount: string;
  discountAmount: string;
  totalAmount: string;
  fulfillmentStatus: OrderFulfillmentStatus;
  paymentStatus: OrderPaymentStatus;
  paymentMethod: OrderPaymentMethod;
  idempotencyKey: string | null;
  cancellationReason: string | null;
  cancelledAt: string | null;
  items: OrderItemModel[];
  statusTimeline?: OrderStatusEventModel[];
  createdAt: string;
  updatedAt: string;
}

export interface CreateOrderInput {
  deliveryAddress: string;
  customerPhone: string;
  customerName: string;
  specialInstructions?: string;
  isScheduled?: boolean;
  scheduledFor?: string;
  idempotencyKey: string;
  paymentMethod?: OrderPaymentMethod;
}

export interface CancelOrderInput {
  reason: string;
}

export interface UpdateOrderStatusInput {
  status: OrderFulfillmentStatus;
  note?: string;
}

