<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('crop_risk_runs', function (Blueprint $table) {
            $table->id();
            $table->timestamp('ran_at')->index();
            $table->unsignedInteger('checked')->default(0);
            $table->unsignedInteger('logged')->default(0);
            $table->unsignedInteger('skipped')->default(0);
            $table->unsignedInteger('failed')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('crop_risk_runs');
    }
};
