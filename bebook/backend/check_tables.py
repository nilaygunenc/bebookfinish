import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()
cur.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'orders' ORDER BY ordinal_position")
print('ORDERS:', cur.fetchall())
cur.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'books' ORDER BY ordinal_position")
print('BOOKS:', cur.fetchall())
conn.close()
