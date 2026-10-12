export interface CartItemModel {
  id: string;
  cartId: string;
  menuItemId: string;
  quantity: number;
  itemInstructions: string | null;
  name: string;
  description: string | null;
  price: string;
  effectivePrice: string;
  isVeg: boolean;
  isAvailable: boolean;
  imageUrl: string | null;
  lineTotal: string;
  createdAt: string;
  updatedAt: string;
}

export interface CartModel {
  id: string;
  customerId: string;
  restaurantId: string;
  restaurantName: string;
  restaurantAddress: string;
  specialInstructions: string | null;
  items: CartItemModel[];
  itemCount: number;
  subtotal: string;
  deliveryFee: string;
  taxAmount: string;
  discountAmount: string;
  totalAmount: string;
  createdAt: string;
  updatedAt: string;
}

export interface AddToCartInput {
  restaurantId: string;
  menuItemId: string;
  quantity: number;
  itemInstructions?: string;
  replaceCart?: boolean;
}

export interface UpdateCartItemInput {
  quantity: number;
  itemInstructions?: string;
}

export interface UpdateCartNotesInput {
  specialInstructions?: string;
}

