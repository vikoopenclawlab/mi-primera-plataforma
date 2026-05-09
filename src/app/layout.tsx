export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Mi Primera Plataforma</title>
      </head>
      <body style={{ margin: 0, background: '#fff' }}>{children}</body>
    </html>
  )
}