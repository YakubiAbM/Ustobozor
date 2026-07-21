import 'chat_response_models.dart';
import 'invoice_models.dart';

extension CartToInvoiceDraft on Cart {
  InvoiceDraft toInvoiceDraft() => InvoiceDraft(
        items: items.map((e) => e.toInvoiceItem()).toList(),
        totalPrice: totalPrice,
        currency: currency,
      );
}

extension CartItemToInvoice on CartItem {
  InvoiceItem toInvoiceItem() => InvoiceItem(
        productId: productId,
        name: name,
        qty: qty,
        unit: unit,
        price: price,
        image: image,
        lineTotal: sum,
      );
}

extension InvoiceDraftToCart on InvoiceDraft {
  Cart toCart() => Cart(
        items: items.map((e) => e.toCartItem()).toList(),
        totalPrice: totalPrice,
        currency: currency,
      );
}

extension InvoiceItemToCart on InvoiceItem {
  CartItem toCartItem() => CartItem(
        productId: productId,
        name: name,
        qty: qty,
        price: price,
        sum: lineTotal,
        unit: unit,
        image: image,
      );
}
