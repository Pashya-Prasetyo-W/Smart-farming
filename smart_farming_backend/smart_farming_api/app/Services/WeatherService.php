<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Exception;

class WeatherService
{
    public function getForecast(float $lat, float $lon): array
    {
        $apiKey = config('services.openweather.key');

        $response = Http::get('https://api.openweathermap.org/data/2.5/forecast', [
            'lat'   => $lat,
            'lon'   => $lon,
            'appid' => $apiKey,
            'units' => 'metric',
        ]);

        if (!$response->successful()) {
            Log::error('Gagal mengambil data dari OpenWeatherMap API: ' . $response->body());
            
            throw new Exception('Layanan cuaca sedang tidak tersedia. Silakan coba beberapa saat lagi.');
        }

        return $response->json();
    }
}