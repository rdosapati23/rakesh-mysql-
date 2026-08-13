CREATE DATABASE EcomDB;
USE EcomDB;
CREATE TABLE customers (
    customer_id   INT IDENTITY(1,1) PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    phone         VARCHAR(20),
    city          VARCHAR(100),
    created_at    DATETIME DEFAULT GETDATE()
);
CREATE TABLE products (
    product_id     INT IDENTITY(1,1) PRIMARY KEY,
    product_name   VARCHAR(150) NOT NULL,
    category       VARCHAR(100) NOT NULL,
    price          DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);
 
CREATE TABLE orders (
    order_id     INT IDENTITY(1,1) PRIMARY KEY,
    customer_id  INT NOT NULL,
    product_id   INT NOT NULL,
    quantity     INT NOT NULL CHECK (quantity > 0),
    order_date   DATE NOT NULL,
    total_price  DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_orders_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE NO ACTION
);
INSERT INTO customers (customer_name, email, phone, city) VALUES
('Aditi Sharma',   'aditi.sharma@mail.com',   '9000000001', 'Hyderabad'),
('Rohan Verma',    'rohan.verma@mail.com',    '9000000002', 'Bengaluru'),
('Sneha Patil',    'sneha.patil@mail.com',    '9000000003', 'Pune'),
('Karan Mehta',    'karan.mehta@mail.com',    '9000000004', 'Delhi'),
('Priya Nair',     'priya.nair@mail.com',     '9000000005', 'Chennai');

INSERT INTO products (product_name, category, price, stock_quantity) VALUES
('Wireless Mouse',       'Electronics', 599.00,  50),
('Mechanical Keyboard',  'Electronics', 2999.00, 30),
('USB-C Hub',            'Electronics', 1299.00, 40),
('Office Chair',         'Furniture',   7999.00, 15),
('Study Desk',           'Furniture',   9999.00, 10);
INSERT INTO orders (customer_id, product_id, quantity, order_date, total_price) VALUES
(1, 1, 2, '2026-01-05', 1198.00),
(1, 3, 1, '2026-02-10', 1299.00),
(2, 2, 1, '2026-01-15', 2999.00),
(3, 4, 1, '2026-03-01', 7999.00),
(3, 1, 1, '2026-03-20', 599.00),
(4, 5, 1, '2026-02-25', 9999.00),
(4, 2, 2, '2026-04-02', 5998.00),
(5, 3, 3, '2026-04-10', 3897.00);

SELECT *
FROM orders
WHERE customer_id = 1;

UPDATE products
SET stock_quantity = stock_quantity - 2
WHERE product_id = 1;

DELETE FROM products
WHERE product_id NOT IN (
    SELECT DISTINCT product_id FROM orders
);
INSERT INTO products (product_name, category, price, stock_quantity)
VALUES ('Test Widget', 'Misc', 199.00, 5);

DELETE FROM products
WHERE product_id NOT IN (
    SELECT DISTINCT product_id FROM orders
);

select * from products

SELECT
    o.order_id AS Order_ID,
    c.customer_name AS Customer_Name,
    p.product_name AS Product_Name,
    o.quantity AS Quantity_Ordered,
    o.total_price AS Total_Price
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN products  p ON o.product_id  = p.product_id
ORDER BY o.order_id;

SELECT
    c.customer_name,
    SUM(o.total_price) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_spent DESC;

-- 3. Top selling product (by total quantity sold)
SELECT TOP 1
    p.product_name,
    SUM(o.quantity) AS total_quantity_sold
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_quantity_sold DESC;
GO

-- 4. Customers who spent more than the average spending across all customers
SELECT
    c.customer_name,
    SUM(o.total_price) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING SUM(o.total_price) > (
    SELECT AVG(customer_total)
    FROM (
        SELECT SUM(total_price) AS customer_total
        FROM orders
        GROUP BY customer_id
    ) AS per_customer_totals
)
ORDER BY total_spent DESC;
--a. Rank the products within each category based on their price (descending)
SELECT
    product_id,
    product_name,
    category,
    price,
    RANK()       OVER (PARTITION BY category ORDER BY price DESC) AS price_rank,
    DENSE_RANK() OVER (PARTITION BY category ORDER BY price DESC) AS price_dense_rank
FROM products
ORDER BY category, price DESC;

/*   - RANK() leaves a gap in the ranking sequence equal to the number
     of tied rows. E.g. if two products tie for rank 1, the next
     product gets rank 3 (rank 2 is skipped).

   - DENSE_RANK() does NOT leave gaps. After the same tie, the next
     product gets rank 2, keeping the ranks consecutive.*/


-- 2. Running total of spending for a specific customer (example: customer_id = 4)
SELECT
    order_id,
    order_date,
    total_price AS order_amount,
    SUM(total_price) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM orders
WHERE customer_id = 4
ORDER BY order_date, order_id

-- 3. Indexing for performance
CREATE NONCLUSTERED INDEX idx_orders_order_date ON orders(order_date);

/*
   Why indexing speeds up retrieval:
   Without an index, a query filtering or sorting on order_date
   (e.g. WHERE order_date BETWEEN ... or ORDER BY order_date) forces
   SQL Server to perform a full table/clustered index scan, checking
   every row in the orders table one by one — an O(n) operation.

   A nonclustered index on order_date builds a separate, sorted
   B-Tree structure that maps order_date values to the rows that
   contain them (via a row locator back to the clustered index).
   This lets the engine use seek operations — roughly O(log n) —
   instead of scanning the whole table. It especially helps:
     - Point lookups: WHERE order_date = '2026-04-02'
     - Range scans: WHERE order_date BETWEEN 'X' AND 'Y'
     - ORDER BY order_date (avoids an expensive sort operator)
     - JOINs/GROUP BYs that reference order_date

   Trade-off: indexes speed up reads but add overhead on
   INSERT/UPDATE/DELETE (the index must be maintained) and consume
   extra disk space, so indexes should be added deliberately on
   columns that are frequently filtered/sorted/joined on — like
   order_date here — rather than on every column.
*/

CREATE TABLE order_audit (
    audit_id     INT IDENTITY(1,1) PRIMARY KEY,
    order_id     INT NOT NULL,
    action_time  DATETIME DEFAULT GETDATE(),
    action_msg   VARCHAR(255) NOT NULL
);

CREATE TRIGGER trg_after_order_insert
ON orders
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO order_audit (order_id, action_time, action_msg)
    SELECT
        i.order_id,
        GETDATE(),
        CONCAT('New order #', i.order_id, ' placed by customer ',
               i.customer_id, ' for product ', i.product_id,
               ' (qty: ', i.quantity, ')')
    FROM inserted i;
END;
GO

CREATE PROCEDURE PlaceOrder
    @p_customer_id INT,
    @p_product_id  INT,
    @p_quantity    INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- ensures the transaction auto-rolls back on error

    DECLARE @v_stock       INT;
    DECLARE @v_price       DECIMAL(10,2);
    DECLARE @v_total_price DECIMAL(10,2);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Lock the product row while we check stock, to avoid race conditions
        SELECT
            @v_stock = stock_quantity,
            @v_price = price
        FROM products WITH (UPDLOCK, ROWLOCK)
        WHERE product_id = @p_product_id;

        IF @v_stock IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50000, 'Product does not exist.', 1;
        END

        IF @v_stock < @p_quantity
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50001, 'Insufficient stock to place this order.', 1;
        END

        SET @v_total_price = @v_price * @p_quantity;

        INSERT INTO orders (customer_id, product_id, quantity, order_date, total_price)
        VALUES (@p_customer_id, @p_product_id, @p_quantity, CAST(GETDATE() AS DATE), @v_total_price);

        UPDATE products
        SET stock_quantity = stock_quantity - @p_quantity
        WHERE product_id = @p_product_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;  -- re-raise the original error to the caller
    END CATCH
END;
GO

CREATE LOGIN junior_analyst WITH PASSWORD = 'ChangeMe_123!';
GO

USE EcomDB;
GO
CREATE USER junior_analyst FOR LOGIN junior_analyst;
GO

GRANT SELECT ON dbo.products  TO junior_analyst;
GRANT SELECT ON dbo.customers TO junior_analyst;
GO

SELECT
    pr.permission_name,
    o.name AS object_name
FROM sys.database_permissions pr
JOIN sys.objects o ON pr.major_id = o.object_id
JOIN sys.database_principals dp ON pr.grantee_principal_id = dp.principal_id
WHERE dp.name = 'junior_analyst';
GO

REVOKE SELECT ON dbo.customers FROM junior_analyst;
GO

SELECT
    pr.permission_name,
    o.name AS object_name
FROM sys.database_permissions pr
JOIN sys.objects o ON pr.major_id = o.object_id
JOIN sys.database_principals dp ON pr.grantee_principal_id = dp.principal_id
WHERE dp.name = 'junior_analyst';
GO




